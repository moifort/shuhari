import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { Count } from '~/domain/shared/primitives'
import type { UserId } from '~/domain/shared/types'
import { fakeFirebase, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', fakeFirebase)

const { QuotaCommand } = await import('~/domain/quota/command')
const { QuotaQuery } = await import('~/domain/quota/query')
const { FREE_LIMITS, monthOf } = await import('~/domain/quota/business-rules')

const userId = 'user-1' as UserId
const month = monthOf(new Date())
const docId = `${userId}_${month}`

let fake = resetFakeFirestore()
beforeEach(() => {
  fake = resetFakeFirestore()
})

describe('QuotaCommand.spend', () => {
  test('creates the month document on the first AI call', async () => {
    await QuotaCommand.spend(userId, 'free', 'import')

    const stored = fake.snapshot('ai-quotas').get(docId)
    expect(stored).toEqual({ userId, month, imports: 1, iterations: 0 })
  })

  test('increments only the meter of the action', async () => {
    await QuotaCommand.spend(userId, 'free', 'import')
    await QuotaCommand.spend(userId, 'free', 'iteration')
    await QuotaCommand.spend(userId, 'free', 'iteration')

    expect(fake.snapshot('ai-quotas').get(docId)).toEqual({
      userId,
      month,
      imports: 1,
      iterations: 2,
    })
  })

  test('is a single-document read-modify-write, in one transaction and no batch', async () => {
    const docReadsBefore = fake.docReads
    const batchesBefore = fake.batches.length

    await QuotaCommand.spend(userId, 'free', 'import')

    expect(fake.docReads - docReadsBefore).toBe(1)
    expect(fake.queryReads).toBe(0)
    expect(fake.batches.length).toBe(batchesBefore)
    // The set rides in the transaction that read the counter, never on its own:
    // that pairing is what makes the increment atomic.
    expect(fake.directWrites).toEqual([])
    expect(fake.transactions).toEqual([
      [
        {
          type: 'set',
          ref: expect.objectContaining({ collection: 'ai-quotas', id: docId }),
          data: expect.anything(),
        },
      ],
    ])
  })

  test('counts every concurrent call — the meter guards the AI bill', async () => {
    // Three AI calls asked at the same moment. Read-then-set had them all read zero
    // and all write one — the freemium limit leaking by exactly the amount of
    // concurrency.
    await Promise.all([
      QuotaCommand.spend(userId, 'free', 'iteration'),
      QuotaCommand.spend(userId, 'free', 'iteration'),
      QuotaCommand.spend(userId, 'free', 'iteration'),
    ])

    expect(fake.snapshot('ai-quotas').get(docId)?.iterations).toBe(3)
  })

  test('keeps each cook on their own document', async () => {
    const other = 'user-2' as UserId
    await QuotaCommand.spend(userId, 'free', 'import')
    await QuotaCommand.spend(other, 'free', 'import')

    expect(fake.snapshot('ai-quotas').get(docId)?.imports).toBe(1)
    expect(fake.snapshot('ai-quotas').get(`${other}_${month}`)?.imports).toBe(1)
  })
})

describe('the limit', () => {
  test('refuses the call past the free limit, and writes nothing for it', async () => {
    for (const _ of Array(FREE_LIMITS.import).keys())
      await QuotaCommand.spend(userId, 'free', 'import')
    const transactions = fake.transactions.length

    expect(await QuotaCommand.spend(userId, 'free', 'import')).toBe('quota-exhausted')
    expect(fake.transactions.length).toBe(transactions)
    // The other meter is untouched.
    expect(await QuotaCommand.spend(userId, 'free', 'iteration')).not.toBe('quota-exhausted')
  })

  test('lets exactly the limit through when every call lands together', async () => {
    // Checked before the call and recorded after it, all of these passed the check
    // on the same count: the limit was a suggestion under concurrency.
    const answers = await Promise.all(
      Array.from({ length: FREE_LIMITS.iteration + 2 }, () =>
        QuotaCommand.spend(userId, 'free', 'iteration'),
      ),
    )

    expect(answers.filter((answer) => answer === 'quota-exhausted')).toHaveLength(2)
    expect(fake.snapshot('ai-quotas').get(docId)?.iterations).toBe(FREE_LIMITS.iteration)
  })

  test('a Premium cook is never exhausted, and is still counted', async () => {
    for (const _ of Array(FREE_LIMITS.import + 1).keys())
      expect(await QuotaCommand.spend(userId, 'premium', 'import')).not.toBe('quota-exhausted')
    expect(fake.snapshot('ai-quotas').get(docId)?.imports).toBe(FREE_LIMITS.import + 1)
  })
})

describe('QuotaCommand.refund', () => {
  test('gives the spent call back to the month it was spent in', async () => {
    const spent = await QuotaCommand.spend(userId, 'free', 'iteration')
    if (spent === 'quota-exhausted') throw new Error('expected a spend')

    await QuotaCommand.refund(spent, 'iteration')

    expect(fake.snapshot('ai-quotas').get(docId)?.iterations).toBe(0)
  })

  test('never turns into credit', async () => {
    const spent = await QuotaCommand.spend(userId, 'free', 'import')
    if (spent === 'quota-exhausted') throw new Error('expected a spend')

    await QuotaCommand.refund(spent, 'import')
    await QuotaCommand.refund(spent, 'import')

    expect(fake.snapshot('ai-quotas').get(docId)?.imports).toBe(0)
  })
})

describe('QuotaQuery', () => {
  test('reads zeros for a month nothing was spent in', async () => {
    expect(await QuotaQuery.current(userId)).toEqual({
      userId,
      month,
      imports: Count(0),
      iterations: Count(0),
    })
  })

  test('reads back what was spent, past the memoized pre-write value', async () => {
    await QuotaQuery.current(userId)
    await QuotaCommand.spend(userId, 'free', 'iteration')
    expect((await QuotaQuery.current(userId)).iterations).toBe(Count(1))
  })
})
