import { describe, expect, test } from 'bun:test'
import { appAccountToken, isActive, planOf } from '~/domain/entitlement/business-rules'
import type { Entitlement } from '~/domain/entitlement/types'
import type { UserId } from '~/domain/shared/types'

const NOW = new Date('2026-07-20T12:00:00.000Z')
const userId = 'user-1' as UserId

const entitlement = (overrides: Partial<Entitlement> = {}): Entitlement =>
  ({
    userId,
    productId: 'com.polyforms.shuhari.app.premium.yearly',
    originalTransactionId: '2000000123456789',
    appAccountToken: appAccountToken(userId),
    expiresAt: new Date('2027-07-20T12:00:00.000Z'),
    updatedAt: NOW,
    ...overrides,
  }) as Entitlement

describe('appAccountToken', () => {
  test('is a stable version-5 UUID for a given cook', () => {
    const token = appAccountToken(userId)
    expect(token).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/)
    // Derived, never stored: the same cook must get the same token forever, on
    // any instance, after any reinstall.
    expect(appAccountToken(userId)).toBe(token)
  })

  test('gives two cooks two different tokens', () => {
    expect(appAccountToken('user-2' as UserId)).not.toBe(appAccountToken(userId))
  })

  test('is frozen — this vector must never change', () => {
    // A change of namespace or algorithm silently detaches every subscription
    // already sold from its cook. This vector is the tripwire.
    expect(appAccountToken('dev-user' as UserId) as string).toBe(
      '957b8c46-3dc8-586d-bd57-7ca3d864a308',
    )
  })
})

describe('isActive', () => {
  test('runs to the paid-for date', () => {
    expect(isActive(entitlement(), NOW)).toBe(true)
    expect(isActive(entitlement({ expiresAt: new Date('2026-07-20T11:59:59.000Z') }), NOW)).toBe(
      false,
    )
  })

  test('a refund ends it on the spot, whatever the expiry says', () => {
    expect(isActive(entitlement({ revokedAt: NOW }), NOW)).toBe(false)
  })
})

describe('planOf', () => {
  test('is premium only while the entitlement is active', () => {
    expect(planOf(entitlement(), NOW)).toBe('premium')
    expect(planOf(undefined, NOW)).toBe('free')
    expect(planOf(entitlement({ expiresAt: new Date('2026-01-01T00:00:00.000Z') }), NOW)).toBe(
      'free',
    )
    expect(planOf(entitlement({ revokedAt: NOW }), NOW)).toBe('free')
  })
})
