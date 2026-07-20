import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

const deleted: string[] = []
mock.module('~/system/firebase', () => ({
  db: fakeDb,
  auth: () => ({
    deleteUser: async (uid: string) => {
      deleted.push(uid)
    },
  }),
}))

const { AccountUseCase } = await import('~/system/account/use-case')

const cook = 'user-1' as UserId
const other = 'user-2' as UserId

let fake = resetFakeFirestore()
beforeEach(() => {
  fake = resetFakeFirestore()
  deleted.length = 0

  fake.seed('recipes', 'r1', { id: 'r1', userId: cook, title: 'Bourguignon' })
  fake.seed('recipes', 'r2', { id: 'r2', userId: other, title: 'Risotto' })
  fake.seed('recipe-versions', 'r1_1', { recipeId: 'r1', userId: cook, number: 1 })
  fake.seed('recipe-versions', 'r2_1', { recipeId: 'r2', userId: other, number: 1 })
  fake.seed('ai-quotas', `${cook}_2026-07`, { userId: cook, month: '2026-07', imports: 2 })
  fake.seed('ai-quotas', `${cook}_2026-06`, { userId: cook, month: '2026-06', imports: 1 })
  fake.seed('ai-quotas', `${other}_2026-07`, { userId: other, month: '2026-07', imports: 3 })
  fake.seed('entitlements', cook, { userId: cook, productId: 'premium.monthly' })
  fake.seed('entitlements', other, { userId: other, productId: 'premium.yearly' })
})

describe('AccountUseCase.remove', () => {
  test('erases the recipes and every version of them', async () => {
    await AccountUseCase.remove(cook)

    expect([...fake.snapshot('recipes').keys()]).toEqual(['r2'])
    expect([...fake.snapshot('recipe-versions').keys()]).toEqual(['r2_1'])
  })

  test('erases every month of the AI allowance, not only the current one', async () => {
    await AccountUseCase.remove(cook)

    expect([...fake.snapshot('ai-quotas').keys()]).toEqual([`${other}_2026-07`])
  })

  test('erases the entitlement', async () => {
    await AccountUseCase.remove(cook)

    expect([...fake.snapshot('entitlements').keys()]).toEqual([other])
  })

  test('deletes the authentication account itself', async () => {
    await AccountUseCase.remove(cook)

    expect(deleted).toEqual([cook])
  })

  test('deletes the account only after the data, never before', async () => {
    await AccountUseCase.remove(cook)

    // Nothing of this cook may outlive the account: were the order reversed, a
    // failure would strand documents keyed to a user nobody can authenticate as.
    expect(fake.snapshot('recipes').has('r1')).toBe(false)
    expect(fake.snapshot('entitlements').has(cook)).toBe(false)
    expect(deleted).toEqual([cook])
  })

  test('leaves every other cook untouched', async () => {
    await AccountUseCase.remove(cook)

    expect(fake.snapshot('recipes').get('r2')).toMatchObject({ userId: other })
    expect(fake.snapshot('ai-quotas').get(`${other}_2026-07`)).toMatchObject({ imports: 3 })
    expect(fake.snapshot('entitlements').get(other)).toMatchObject({ userId: other })
    expect(deleted).not.toContain(other)
  })
})
