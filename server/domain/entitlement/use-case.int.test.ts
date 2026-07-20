import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { UserId } from '~/domain/shared/types'
import type { AppleNotification, AppleTransaction } from '~/system/apple/types'
import { fakeFirebase, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', fakeFirebase)
mock.module('~/system/config', () => ({ config: () => ({ premiumUserIds: [] }) }))

// Apple's signature check is mocked: these tests are about what the domain does
// with a verified payload, not about cryptography (that is the library's job).
let transaction: AppleTransaction | 'invalid-signature'
let notification: AppleNotification | 'invalid-signature'
mock.module('~/system/apple', () => ({
  Apple: {
    verifyTransaction: async () => transaction,
    verifyNotification: async () => notification,
  },
}))

const { EntitlementUseCase } = await import('~/domain/entitlement/use-case')
const { EntitlementQuery } = await import('~/domain/entitlement/query')
const { appAccountToken } = await import('~/domain/entitlement/business-rules')

const userId = 'user-1' as UserId
const NEXT_YEAR = new Date(Date.now() + 365 * 24 * 3600 * 1000)

const validTransaction = (overrides: Partial<AppleTransaction> = {}): AppleTransaction => ({
  productId: 'com.polyforms.shuhari.app.premium.yearly',
  originalTransactionId: '2000000123456789',
  appAccountToken: appAccountToken(userId) as string,
  expiresAt: NEXT_YEAR,
  ...overrides,
})

let fake = resetFakeFirestore()
beforeEach(() => {
  fake = resetFakeFirestore()
  transaction = validTransaction()
  notification = { type: 'DID_RENEW', transaction: validTransaction() }
})

describe('EntitlementUseCase.sync', () => {
  test('records the purchase and turns the cook Premium', async () => {
    const result = await EntitlementUseCase.sync(userId, 'eyJ...')
    if (typeof result === 'string') throw new Error('expected an entitlement')

    expect(result.productId as string).toBe('com.polyforms.shuhari.app.premium.yearly')
    expect(fake.snapshot('entitlements').get(userId)?.originalTransactionId).toBe(
      '2000000123456789',
    )
    expect(await EntitlementQuery.planOf(userId)).toBe('premium')
  })

  test('refuses a transaction Apple did not sign', async () => {
    transaction = 'invalid-signature'
    expect(await EntitlementUseCase.sync(userId, 'forged')).toBe('invalid-transaction')
    expect(fake.snapshot('entitlements').size).toBe(0)
  })

  test('refuses a purchase made for another account', async () => {
    // Signed by Apple, genuinely paid for — by somebody else. The account token
    // is what tells the two apart.
    transaction = validTransaction({
      appAccountToken: appAccountToken('user-2' as UserId) as string,
    })
    expect(await EntitlementUseCase.sync(userId, 'eyJ...')).toBe('transaction-not-yours')
    expect(fake.snapshot('entitlements').size).toBe(0)
  })

  test('refuses a purchase carrying no account token at all', async () => {
    transaction = validTransaction({ appAccountToken: undefined })
    expect(await EntitlementUseCase.sync(userId, 'eyJ...')).toBe('invalid-transaction')
  })

  test('refuses a purchase that grants no time', async () => {
    transaction = validTransaction({ expiresAt: undefined })
    expect(await EntitlementUseCase.sync(userId, 'eyJ...')).toBe('invalid-transaction')
  })

  test('a renewal overwrites in place — one entitlement per cook', async () => {
    await EntitlementUseCase.sync(userId, 'eyJ...')
    const later = new Date(NEXT_YEAR.getTime() + 365 * 24 * 3600 * 1000)
    transaction = validTransaction({ expiresAt: later })
    await EntitlementUseCase.sync(userId, 'eyJ...')

    expect(fake.snapshot('entitlements').size).toBe(1)
    expect((await EntitlementQuery.of(userId))?.expiresAt).toEqual(later)
  })

  test('an expired entitlement drops the cook back to free', async () => {
    transaction = validTransaction({ expiresAt: new Date(Date.now() - 1000) })
    await EntitlementUseCase.sync(userId, 'eyJ...')
    expect(await EntitlementQuery.planOf(userId)).toBe('free')
  })
})

describe('EntitlementUseCase.applyNotification', () => {
  test('extends a known cook’s entitlement on a renewal', async () => {
    await EntitlementUseCase.sync(userId, 'eyJ...')
    const later = new Date(NEXT_YEAR.getTime() + 365 * 24 * 3600 * 1000)
    notification = { type: 'DID_RENEW', transaction: validTransaction({ expiresAt: later }) }

    expect(await EntitlementUseCase.applyNotification('eyJ...')).toBe('applied')
    expect((await EntitlementQuery.of(userId))?.expiresAt).toEqual(later)
  })

  test('a refund revokes Premium immediately', async () => {
    await EntitlementUseCase.sync(userId, 'eyJ...')
    notification = {
      type: 'REFUND',
      transaction: validTransaction({ revokedAt: new Date() }),
    }

    expect(await EntitlementUseCase.applyNotification('eyJ...')).toBe('applied')
    // The paid-for date has not moved — the revocation is what ends it.
    expect(await EntitlementQuery.planOf(userId)).toBe('free')
  })

  test('ignores a notification for a cook we have never recorded', async () => {
    expect(await EntitlementUseCase.applyNotification('eyJ...')).toBe('ignored')
    expect(fake.snapshot('entitlements').size).toBe(0)
  })

  test('refuses a notification Apple did not sign', async () => {
    notification = 'invalid-signature'
    expect(await EntitlementUseCase.applyNotification('forged')).toBe('invalid-notification')
  })
})
