import { describe, expect, test } from 'bun:test'
import {
  allowsUrlImport,
  consumed,
  exhausted,
  FREE_LIMITS,
  freshQuota,
  limitOf,
  monthOf,
  remaining,
  renewsOn,
  used,
} from '~/domain/quota/business-rules'
import type { QuotaMonth } from '~/domain/quota/types'
import { Count } from '~/domain/shared/primitives'
import type { UserId } from '~/domain/shared/types'

const userId = 'user-1' as UserId
const JULY = '2026-07' as QuotaMonth

const quota = (imports: number, iterations: number) => ({
  ...freshQuota(userId, JULY),
  imports: Count(imports),
  iterations: Count(iterations),
})

describe('monthOf', () => {
  test('is the UTC calendar month, zero-padded', () => {
    expect(monthOf(new Date('2026-07-20T14:30:00.000Z'))).toBe(JULY)
    expect(monthOf(new Date('2026-01-01T00:00:00.000Z'))).toBe('2026-01' as QuotaMonth)
  })

  test('does not follow the caller timezone across midnight', () => {
    // 23:30 UTC on the last day of July is still July, wherever the cook stands.
    expect(monthOf(new Date('2026-07-31T23:30:00.000Z'))).toBe(JULY)
  })
})

describe('renewsOn', () => {
  test('is midnight UTC on the 1st of the next month', () => {
    expect(renewsOn(JULY)).toEqual(new Date('2026-08-01T00:00:00.000Z'))
  })

  test('rolls December over to January', () => {
    expect(renewsOn('2026-12' as QuotaMonth)).toEqual(new Date('2027-01-01T00:00:00.000Z'))
  })
})

describe('freshQuota', () => {
  test('is a month with both meters at zero', () => {
    expect(freshQuota(userId, JULY)).toEqual({
      userId,
      month: JULY,
      imports: Count(0),
      iterations: Count(0),
    })
  })
})

describe('used', () => {
  test('reads the meter of the action asked for', () => {
    expect(used(quota(2, 5), 'import')).toBe(Count(2))
    expect(used(quota(2, 5), 'iteration')).toBe(Count(5))
  })
})

describe('limitOf', () => {
  test('is the free allowance on the free plan', () => {
    expect(limitOf('free', 'import')).toBe(FREE_LIMITS.import)
    expect(limitOf('free', 'iteration')).toBe(FREE_LIMITS.iteration)
  })

  test('is absent on premium — unlimited', () => {
    expect(limitOf('premium', 'import')).toBeUndefined()
    expect(limitOf('premium', 'iteration')).toBeUndefined()
  })
})

describe('remaining', () => {
  test('is what the free allowance still holds', () => {
    expect(remaining('free', quota(1, 0), 'import')).toBe(Count(FREE_LIMITS.import - 1))
  })

  test('never goes negative', () => {
    expect(remaining('free', quota(99, 0), 'import')).toBe(Count(0))
  })

  test('is absent on premium', () => {
    expect(remaining('premium', quota(99, 0), 'import')).toBeUndefined()
  })
})

describe('exhausted', () => {
  test('turns true once the free allowance is spent', () => {
    expect(exhausted('free', quota(FREE_LIMITS.import - 1, 0), 'import')).toBe(false)
    expect(exhausted('free', quota(FREE_LIMITS.import, 0), 'import')).toBe(true)
    expect(exhausted('free', quota(0, FREE_LIMITS.iteration), 'iteration')).toBe(true)
  })

  test('is never true on premium', () => {
    expect(exhausted('premium', quota(999, 999), 'import')).toBe(false)
  })
})

describe('allowsUrlImport', () => {
  test('is what the subscription buys', () => {
    expect(allowsUrlImport('premium')).toBe(true)
    expect(allowsUrlImport('free')).toBe(false)
  })
})

describe('consumed', () => {
  test('increments the meter of the action, leaving the other one alone', () => {
    expect(consumed(quota(1, 4), 'import')).toEqual(quota(2, 4))
    expect(consumed(quota(1, 4), 'iteration')).toEqual(quota(1, 5))
  })
})
