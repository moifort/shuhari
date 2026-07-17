import { describe, expect, test } from 'bun:test'
import type { Param, ParamKey, ParamValue } from '~/domain/recipe/types'
import {
  averageNote,
  highestNote,
  realDeviations,
  replayParams,
} from '~/domain/trial/business-rules'
import type { Note } from '~/domain/trial/types'

const param = (key: string, value: string): Param => ({
  key: key as ParamKey,
  value: value as ParamValue,
})

describe('realDeviations', () => {
  const target = [param('Dose', '18 g'), param('Température', '93 °C')]
  test('keeps only the parameters that changed', () => {
    const entered = [param('Dose', '18 g'), param('Température', '90 °C')]
    expect(realDeviations(target, entered)).toEqual([param('Température', '90 °C')])
  })
  test('returns empty when nothing deviated', () => {
    expect(realDeviations(target, [param('Dose', '18 g'), param('Température', '93 °C')])).toEqual(
      [],
    )
  })
  test('treats a key absent from targets as a deviation', () => {
    expect(realDeviations(target, [param('Grind', 'fine')])).toEqual([param('Grind', 'fine')])
  })
})

describe('replayParams', () => {
  const target = [param('Dose', '18 g'), param('Température', '93 °C')]
  test('overlays the real deviations onto the targets, order preserved', () => {
    const real = [param('Température', '90 °C')]
    expect(replayParams(target, real)).toEqual([
      param('Dose', '18 g'),
      param('Température', '90 °C'),
    ])
  })
  test('returns the targets unchanged when there were no deviations', () => {
    expect(replayParams(target, [])).toEqual(target)
  })
  test('appends real-only keys not present in the targets', () => {
    const real = [param('Grind', 'fine')]
    expect(replayParams(target, real)).toEqual([...target, param('Grind', 'fine')])
  })
})

describe('averageNote', () => {
  const note = (n: number) => n as Note
  test('returns null for no trials', () => {
    expect(averageNote([])).toBeNull()
  })
  test('averages and rounds to one decimal', () => {
    expect(averageNote([note(3), note(4), note(5)])).toBe(4)
    expect(averageNote([note(4), note(5)])).toBe(4.5)
    expect(averageNote([note(4), note(5), note(5)])).toBeCloseTo(4.7, 5)
  })
})

describe('highestNote', () => {
  const note = (n: number) => n as Note
  test('returns null for no trials', () => {
    expect(highestNote([])).toBeNull()
  })
  test('returns the best note', () => {
    expect(highestNote([note(2), note(5), note(3)])).toBe(note(5))
  })
  test('handles a single note', () => {
    expect(highestNote([note(4)])).toBe(note(4))
  })
})
