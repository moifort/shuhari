import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { Count } from '~/domain/shared/primitives'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

// The plan comes from configuration until in-app purchase ships (see `QuotaQuery.planOf`).
let premiumUserIds: UserId[] = []
mock.module('~/system/config', () => ({ config: () => ({ premiumUserIds }) }))

const { QuotaCommand } = await import('~/domain/quota/command')
const { QuotaQuery } = await import('~/domain/quota/query')
const { FREE_LIMITS, monthOf } = await import('~/domain/quota/business-rules')

const userId = 'user-1' as UserId
const month = monthOf(new Date())
const docId = `${userId}_${month}`

let fake = resetFakeFirestore()
beforeEach(() => {
  fake = resetFakeFirestore()
  premiumUserIds = []
})

describe('QuotaCommand.record', () => {
  test('creates the month document on the first AI call', async () => {
    await QuotaCommand.record(userId, 'import')

    const stored = fake.snapshot('ai-quotas').get(docId)
    expect(stored).toEqual({ userId, month, imports: 1, iterations: 0 })
  })

  test('increments only the meter of the action', async () => {
    await QuotaCommand.record(userId, 'import')
    await QuotaCommand.record(userId, 'iteration')
    await QuotaCommand.record(userId, 'iteration')

    expect(fake.snapshot('ai-quotas').get(docId)).toEqual({
      userId,
      month,
      imports: 1,
      iterations: 2,
    })
  })

  test('is a single-document write — one read, one set, no batch', async () => {
    const docReadsBefore = fake.docReads
    const batchesBefore = fake.batches.length

    await QuotaCommand.record(userId, 'import')

    expect(fake.docReads - docReadsBefore).toBe(1)
    expect(fake.queryReads).toBe(0)
    expect(fake.batches.length).toBe(batchesBefore)
    expect(fake.directWrites).toEqual([{ type: 'set', collection: 'ai-quotas', id: docId }])
  })

  test('keeps each cook on their own document', async () => {
    const other = 'user-2' as UserId
    await QuotaCommand.record(userId, 'import')
    await QuotaCommand.record(other, 'import')

    expect(fake.snapshot('ai-quotas').get(docId)?.imports).toBe(1)
    expect(fake.snapshot('ai-quotas').get(`${other}_${month}`)?.imports).toBe(1)
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

  test('reads back what was recorded, past the memoized pre-write value', async () => {
    await QuotaCommand.record(userId, 'iteration')
    expect((await QuotaQuery.current(userId)).iterations).toBe(Count(1))
  })

  test('exhaustedFor turns true exactly at the free limit', async () => {
    for (const _ of Array(FREE_LIMITS.import - 1).keys())
      await QuotaCommand.record(userId, 'import')
    expect(await QuotaQuery.exhaustedFor(userId, 'import')).toBe(false)

    await QuotaCommand.record(userId, 'import')
    expect(await QuotaQuery.exhaustedFor(userId, 'import')).toBe(true)
    // The other meter is untouched.
    expect(await QuotaQuery.exhaustedFor(userId, 'iteration')).toBe(false)
  })

  test('planOf reads the configured Premium cooks, everyone else is free', async () => {
    expect(await QuotaQuery.planOf(userId)).toBe('free')
    premiumUserIds = [userId]
    expect(await QuotaQuery.planOf(userId)).toBe('premium')
    expect(await QuotaQuery.planOf('user-2' as UserId)).toBe('free')
  })

  test('a Premium cook is never exhausted', async () => {
    premiumUserIds = [userId]
    for (const _ of Array(FREE_LIMITS.import + 1).keys())
      await QuotaCommand.record(userId, 'import')
    expect(await QuotaQuery.exhaustedFor(userId, 'import')).toBe(false)
  })
})
