import { describe, expect, test } from 'bun:test'
import {
  alignedTmxSteps,
  bestNote,
  categoryRank,
  nextVersionNumber,
  toTmxSettings,
  versionToOpen,
} from '~/domain/recipe/business-rules'
import {
  DISH_CATEGORY_VALUES,
  type Note,
  type RecipeVersion,
  type StepText,
  type TmxSettings,
  type TmxSpeed,
  type TmxTemperature,
  type TmxTime,
  type VersionNumber,
} from '~/domain/recipe/types'

const v = (n: number) => n as VersionNumber
const note = (n: number) => n as Note

// Minimal RecipeVersion fixture: bestNote/versionToOpen only read `number`, `note`
// and `basedOn`. An absent note means the version was never cooked (no rating).
const version = (number: number, opts: { note?: number; basedOn?: number } = {}): RecipeVersion =>
  ({
    number: v(number),
    note: opts.note === undefined ? null : note(opts.note),
    basedOn: opts.basedOn === undefined ? null : v(opts.basedOn),
  }) as RecipeVersion

describe('categoryRank', () => {
  test('ranks the courses in business order, not alphabetically', () => {
    expect(categoryRank('entree')).toBe(0)
    expect(categoryRank('plat')).toBe(1)
    expect(categoryRank('dessert')).toBe(2)
    expect(categoryRank('soupe')).toBe(3)
    expect(categoryRank('sauce')).toBe(4)
    expect(categoryRank('boulangerie')).toBe(5)
  })
  test('an entrée outranks a dessert which outranks a boulangerie (non-alphabetical)', () => {
    expect(categoryRank('entree')).toBeLessThan(categoryRank('dessert'))
    expect(categoryRank('dessert')).toBeLessThan(categoryRank('boulangerie'))
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

describe('bestNote', () => {
  test('returns null when no version was ever cooked', () => {
    expect(bestNote([])).toBeNull()
    expect(bestNote([version(1), version(2)])).toBeNull()
  })
  test('returns the highest-noted version', () => {
    const v2 = version(2, { note: 5 })
    expect(bestNote([version(1, { note: 3 }), v2, version(3, { note: 4 })])).toBe(v2)
  })
  test('breaks a note tie toward the most recent version', () => {
    const v3 = version(3, { note: 4 })
    expect(bestNote([version(1, { note: 4 }), v3, version(2, { note: 4 })])).toBe(v3)
  })
  test('ignores never-cooked versions', () => {
    const v1 = version(1, { note: 4 })
    expect(bestNote([v1, version(2), version(3)])).toBe(v1)
  })
})

describe('versionToOpen', () => {
  test('opens the latest version when nothing was ever rated', () => {
    const v3 = version(3)
    expect(versionToOpen([version(1), version(2), v3])).toBe(v3)
  })
  test('opens the best-noted version when it has no version derived from it', () => {
    const v1 = version(1, { note: 5 })
    expect(versionToOpen([v1, version(2, { note: 3 })])).toBe(v1)
  })
  test('opens the essai en cours: the version derived from the best-noted one', () => {
    const v2 = version(2, { basedOn: 1 })
    expect(versionToOpen([version(1, { note: 5 }), v2])).toBe(v2)
  })
  test('opens the most recent version derived from the best-noted one', () => {
    const v3 = version(3, { basedOn: 1 })
    expect(versionToOpen([version(1, { note: 5 }), version(2, { basedOn: 1 }), v3])).toBe(v3)
  })
  test('ignores versions derived from a non-best version', () => {
    const best = version(2, { note: 5 })
    expect(versionToOpen([version(1, { note: 3 }), best, version(3, { basedOn: 1 })])).toBe(best)
  })
  test('propagates the best-noted tie-break to the essai en cours', () => {
    const v3 = version(3, { basedOn: 2 })
    expect(versionToOpen([version(1, { note: 4 }), version(2, { note: 4 }), v3])).toBe(v3)
  })
})

describe('alignedTmxSteps', () => {
  const steps = ['Mixer', 'Cuire'].map((s) => s as StepText)
  const settings: TmxSettings = { time: '5 min' as TmxTime, speed: '4' as TmxSpeed }

  test('keeps settings aligned with the steps', () => {
    expect(alignedTmxSteps(steps, [settings, null])).toEqual([settings, null])
  })
  test('drops settings whose length differs from the steps', () => {
    expect(alignedTmxSteps(steps, [settings])).toEqual([])
  })
  test('drops settings when every entry is null', () => {
    expect(alignedTmxSteps(steps, [null, null])).toEqual([])
  })
  test('normalizes entries carrying no actual setting to null', () => {
    expect(alignedTmxSteps(steps, [settings, { reverse: false }])).toEqual([settings, null])
    expect(alignedTmxSteps(steps, [{}, { reverse: false }])).toEqual([])
  })
  test('keeps reverse alone as a setting when true', () => {
    expect(alignedTmxSteps(steps, [{ reverse: true }, null])).toEqual([{ reverse: true }, null])
  })
  test('returns [] for an empty list', () => {
    expect(alignedTmxSteps(steps, [])).toEqual([])
  })
})

describe('toTmxSettings', () => {
  test('maps a null/undefined entry to a plain (null) step', () => {
    expect(toTmxSettings([null, undefined])).toEqual([null, null])
  })
  test('drops absent and null fields', () => {
    expect(
      toTmxSettings([
        { time: '5 min' as TmxTime, temperature: null, speed: undefined, reverse: null },
      ]),
    ).toEqual([{ time: '5 min' as TmxTime }])
  })
  test('keeps reverse only when true (false carries no information)', () => {
    expect(toTmxSettings([{ reverse: true }])).toEqual([{ reverse: true }])
    expect(toTmxSettings([{ reverse: false }])).toEqual([{}])
  })
  test('assembles a fully-populated setting', () => {
    const entry = {
      time: '3 min' as TmxTime,
      temperature: '100°C' as TmxTemperature,
      speed: '4' as TmxSpeed,
      reverse: true,
    }
    expect(toTmxSettings([entry])).toEqual([entry])
  })
})
