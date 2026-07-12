import { describe, expect, test } from 'bun:test'
import {
  alignedTmxSteps,
  applyProposalToParams,
  nextVersionNumber,
  PROMOTION_NOTE,
  readyToPromote,
} from '~/domain/recipe/business-rules'
import type {
  Param,
  ParamKey,
  ParamValue,
  StepText,
  TmxSettings,
  TmxSpeed,
  TmxTime,
  VersionNumber,
} from '~/domain/recipe/types'
import type { Note } from '~/domain/trial/types'

const v = (n: number) => n as VersionNumber
const note = (n: number) => n as Note
const param = (key: string, value: string): Param => ({
  key: key as ParamKey,
  value: value as ParamValue,
})

describe('readyToPromote', () => {
  test('promotes when a high note tests exactly the pending version', () => {
    expect(readyToPromote(note(PROMOTION_NOTE), v(4), v(4))).toBe(true)
    expect(readyToPromote(note(10), v(2), v(2))).toBe(true)
  })
  test('does not promote below the threshold', () => {
    expect(readyToPromote(note(7), v(4), v(4))).toBe(false)
  })
  test('does not promote when the tested version is not the pending one', () => {
    expect(readyToPromote(note(9), v(3), v(4))).toBe(false)
  })
  test('does not promote when nothing is pending', () => {
    expect(readyToPromote(note(9), v(3), null)).toBe(false)
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
    expect(alignedTmxSteps(steps, [settings])).toBeUndefined()
  })
  test('drops settings when every entry is null', () => {
    expect(alignedTmxSteps(steps, [null, null])).toBeUndefined()
  })
  test('normalizes entries carrying no actual setting to null', () => {
    expect(alignedTmxSteps(steps, [settings, { reverse: false }])).toEqual([settings, null])
    expect(alignedTmxSteps(steps, [{}, { reverse: false }])).toBeUndefined()
  })
  test('keeps reverse alone as a setting when true', () => {
    expect(alignedTmxSteps(steps, [{ reverse: true }, null])).toEqual([{ reverse: true }, null])
  })
  test('passes through absent settings', () => {
    expect(alignedTmxSteps(steps, undefined)).toBeUndefined()
  })
})

describe('applyProposalToParams', () => {
  test('replaces an existing key in place, preserving order', () => {
    const params = [param('Dose', '18 g'), param('Température', '93 °C')]
    const result = applyProposalToParams(params, [
      { key: 'Température' as ParamKey, value: '92 °C' as ParamValue },
    ])
    expect(result).toEqual([param('Dose', '18 g'), param('Température', '92 °C')])
  })
  test('appends a new key at the end', () => {
    const params = [param('Dose', '18 g')]
    const result = applyProposalToParams(params, [
      { key: 'Pré-infusion' as ParamKey, value: '5 s' as ParamValue },
    ])
    expect(result).toEqual([param('Dose', '18 g'), param('Pré-infusion', '5 s')])
  })
  test('does not mutate the input params', () => {
    const params = [param('Dose', '18 g')]
    applyProposalToParams(params, [{ key: 'Dose' as ParamKey, value: '19 g' as ParamValue }])
    expect(params[0].value).toBe('18 g' as ParamValue)
  })
})
