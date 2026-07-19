import { describe, expect, test } from 'bun:test'
import {
  type LooseThermomixSettings,
  thermomixSteps,
  toThermomixSettings,
} from '~/domain/recipe/content/thermomix'
import type {
  StepText,
  ThermomixSpeed,
  ThermomixTemperature,
  ThermomixTime,
} from '~/domain/recipe/types'

const texts = (...s: string[]) => s.map((x) => x as StepText)
const settings: LooseThermomixSettings = {
  time: '5 min' as ThermomixTime,
  speed: '4' as ThermomixSpeed,
}

describe('thermomixSteps', () => {
  test('pairs each step text with its aligned settings', () => {
    expect(thermomixSteps(texts('Mixer', 'Cuire'), [settings, {}])).toEqual([
      { text: 'Mixer' as StepText, settings },
      { text: 'Cuire' as StepText, settings: {} },
    ])
  })

  test('drops settings whose length differs from the steps — every step turns plain', () => {
    expect(thermomixSteps(texts('Mixer', 'Cuire'), [settings])).toEqual([
      { text: 'Mixer' as StepText, settings: {} },
      { text: 'Cuire' as StepText, settings: {} },
    ])
  })

  test('drops settings when every entry is empty — every step turns plain', () => {
    expect(thermomixSteps(texts('Mixer', 'Cuire'), [{}, {}])).toEqual([
      { text: 'Mixer' as StepText, settings: {} },
      { text: 'Cuire' as StepText, settings: {} },
    ])
  })

  test('normalizes an entry carrying no actual setting to a plain step', () => {
    expect(thermomixSteps(texts('Mixer', 'Cuire'), [settings, { reverse: false }])).toEqual([
      { text: 'Mixer' as StepText, settings },
      { text: 'Cuire' as StepText, settings: {} },
    ])
    expect(thermomixSteps(texts('Mixer', 'Cuire'), [{}, { reverse: false }])).toEqual([
      { text: 'Mixer' as StepText, settings: {} },
      { text: 'Cuire' as StepText, settings: {} },
    ])
  })

  test('keeps reverse alone as a setting when true', () => {
    expect(thermomixSteps(texts('Mixer', 'Cuire'), [{ reverse: true }, {}])).toEqual([
      { text: 'Mixer' as StepText, settings: { reverse: true } },
      { text: 'Cuire' as StepText, settings: {} },
    ])
  })

  test('returns [] for an empty step list', () => {
    expect(thermomixSteps([], [])).toEqual([])
  })
})

describe('toThermomixSettings', () => {
  test('maps an entry with no field to the empty settings object (a plain step)', () => {
    expect(toThermomixSettings([{}, {}])).toEqual([{}, {}])
  })

  test('drops absent fields', () => {
    expect(
      toThermomixSettings([
        { time: '5 min' as ThermomixTime, temperature: undefined, speed: undefined },
      ]),
    ).toEqual([{ time: '5 min' as ThermomixTime }])
  })

  test('keeps reverse only when true (false carries no information)', () => {
    expect(toThermomixSettings([{ reverse: true }])).toEqual([{ reverse: true }])
    expect(toThermomixSettings([{ reverse: false }])).toEqual([{}])
  })

  test('assembles a fully-populated setting', () => {
    const entry = {
      time: '3 min' as ThermomixTime,
      temperature: '100°C' as ThermomixTemperature,
      speed: '4' as ThermomixSpeed,
      reverse: true,
    }
    expect(toThermomixSettings([entry])).toEqual([entry])
  })
})
