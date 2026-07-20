import { describe, expect, test } from 'bun:test'
import {
  bestRating,
  categoryRank,
  nextVersionNumber,
  versionToOpen,
} from '~/domain/recipe/business-rules'
import {
  DISH_CATEGORY_VALUES,
  type Rating,
  type RecipeVersion,
  type VersionNumber,
} from '~/domain/recipe/types'

const v = (n: number) => n as VersionNumber
const rating = (n: number) => n as Rating

// Minimal RecipeVersion fixture: bestRating/versionToOpen only read `number`,
// `rating` and `basedOn`. An absent rating means the version was never cooked.
const version = (number: number, opts: { rating?: number; basedOn?: number } = {}): RecipeVersion =>
  ({
    number: v(number),
    ...(opts.rating === undefined ? {} : { rating: rating(opts.rating) }),
    ...(opts.basedOn === undefined ? {} : { basedOn: v(opts.basedOn) }),
  }) as RecipeVersion

describe('categoryRank', () => {
  test('ranks the courses in business order, not alphabetically', () => {
    expect(categoryRank('starter')).toBe(0)
    expect(categoryRank('main')).toBe(1)
    expect(categoryRank('dessert')).toBe(2)
    expect(categoryRank('soup')).toBe(3)
    expect(categoryRank('sauce')).toBe(4)
    expect(categoryRank('baking')).toBe(5)
    expect(categoryRank('drink')).toBe(6)
  })
  test('a starter outranks a dessert which outranks baking (non-alphabetical)', () => {
    expect(categoryRank('starter')).toBeLessThan(categoryRank('dessert'))
    expect(categoryRank('dessert')).toBeLessThan(categoryRank('baking'))
  })
  test('assigns a distinct rank to every category', () => {
    const ranks = DISH_CATEGORY_VALUES.map(categoryRank)
    expect(new Set(ranks).size).toBe(DISH_CATEGORY_VALUES.length)
  })
})

describe('nextVersionNumber', () => {
  test('increments the highest allocated number', () => {
    expect(nextVersionNumber(v(3))).toBe(v(4))
  })
})

describe('bestRating', () => {
  test('returns nothing when no version was ever cooked', () => {
    expect(bestRating([])).toBeUndefined()
    expect(bestRating([version(1), version(2)])).toBeUndefined()
  })
  test('returns the highest-rated version', () => {
    const v2 = version(2, { rating: 5 })
    expect(bestRating([version(1, { rating: 3 }), v2, version(3, { rating: 4 })])).toBe(v2)
  })
  test('breaks a rating tie toward the most recent version', () => {
    const v3 = version(3, { rating: 4 })
    expect(bestRating([version(1, { rating: 4 }), v3, version(2, { rating: 4 })])).toBe(v3)
  })
  test('ignores never-cooked versions', () => {
    const v1 = version(1, { rating: 4 })
    expect(bestRating([v1, version(2), version(3)])).toBe(v1)
  })
})

describe('versionToOpen', () => {
  test('opens the latest version when nothing was ever rated', () => {
    const v3 = version(3)
    expect(versionToOpen([version(1), version(2), v3])).toBe(v3)
  })
  test('opens the best-rated version when it has no version derived from it', () => {
    const v1 = version(1, { rating: 5 })
    expect(versionToOpen([v1, version(2, { rating: 3 })])).toBe(v1)
  })
  test('opens the attempt in progress: the version derived from the best-rated one', () => {
    const v2 = version(2, { basedOn: 1 })
    expect(versionToOpen([version(1, { rating: 5 }), v2])).toBe(v2)
  })
  test('opens the most recent version derived from the best-rated one', () => {
    const v3 = version(3, { basedOn: 1 })
    expect(versionToOpen([version(1, { rating: 5 }), version(2, { basedOn: 1 }), v3])).toBe(v3)
  })
  test('ignores versions derived from a non-best version', () => {
    const best = version(2, { rating: 5 })
    expect(versionToOpen([version(1, { rating: 3 }), best, version(3, { basedOn: 1 })])).toBe(best)
  })
  test('propagates the best-rated tie-break to the attempt in progress', () => {
    const v3 = version(3, { basedOn: 2 })
    expect(versionToOpen([version(1, { rating: 4 }), version(2, { rating: 4 }), v3])).toBe(v3)
  })
})
