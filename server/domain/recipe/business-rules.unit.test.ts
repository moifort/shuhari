import { describe, expect, test } from 'bun:test'
import {
  alignedTmxSteps,
  categoryRank,
  nextVersionNumber,
  PROMOTION_NOTE,
  readyToPromote,
  toTmxSettings,
} from '~/domain/recipe/business-rules'
import {
  DISH_CATEGORY_VALUES,
  type StepText,
  type TmxSettings,
  type TmxSpeed,
  type TmxTemperature,
  type TmxTime,
  type VersionNumber,
} from '~/domain/recipe/types'
import type { Note } from '~/domain/trial/types'

const v = (n: number) => n as VersionNumber
const note = (n: number) => n as Note

describe('readyToPromote', () => {
  test('promotes when a high note tests exactly the pending version', () => {
    expect(readyToPromote(note(PROMOTION_NOTE), v(4), v(4))).toBe(true)
    expect(readyToPromote(note(5), v(2), v(2))).toBe(true)
  })
  test('does not promote below the threshold', () => {
    expect(readyToPromote(note(3), v(4), v(4))).toBe(false)
  })
  test('does not promote when the tested version is not the pending one', () => {
    expect(readyToPromote(note(5), v(3), v(4))).toBe(false)
  })
  test('does not promote when nothing is pending', () => {
    expect(readyToPromote(note(5), v(3), null)).toBe(false)
  })
})

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
