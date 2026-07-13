import { describe, expect, test } from 'bun:test'
import { parseImportResponse } from '~/system/ai/primitives'

const base = { type: 'tmx', title: 'Risotto' }

describe('parseImportResponse — Thermomix steps', () => {
  test('splits step objects into aligned steps and tmxSteps arrays', () => {
    const result = parseImportResponse(
      JSON.stringify({
        ...base,
        steps: [
          { text: 'Mixer les oignons', tmxTime: '5 s', tmxTemperature: null, tmxSpeed: '5' },
          { text: 'Servir', tmxTime: null, tmxTemperature: null, tmxSpeed: null, tmxReverse: null },
          {
            text: 'Cuire',
            tmxTime: '14 min',
            tmxTemperature: '100°C',
            tmxSpeed: '1',
            tmxReverse: true,
          },
        ],
      }),
    )

    expect(result.steps).toEqual(['Mixer les oignons', 'Servir', 'Cuire'])
    expect(result.tmxSteps).toEqual([
      { time: '5 s', temperature: null, speed: '5', reverse: null },
      null,
      { time: '14 min', temperature: '100°C', speed: '1', reverse: true },
    ])
  })

  test('collapses tmxSteps to null when no step carries a setting', () => {
    const result = parseImportResponse(
      JSON.stringify({
        ...base,
        type: 'plat',
        steps: [{ text: 'Émincer' }, { text: 'Saisir', tmxTime: null, tmxReverse: false }],
      }),
    )

    expect(result.steps).toEqual(['Émincer', 'Saisir'])
    expect(result.tmxSteps).toBeNull()
  })

  test('tolerates bare string steps as plain steps', () => {
    const result = parseImportResponse(JSON.stringify({ ...base, steps: ['Mixer', 'Servir'] }))

    expect(result.steps).toEqual(['Mixer', 'Servir'])
    expect(result.tmxSteps).toBeNull()
  })
})

describe('parseImportResponse — ingredients', () => {
  test('parses the ingredient list with names and quantities', () => {
    const result = parseImportResponse(
      JSON.stringify({
        type: 'cocktail',
        title: 'Negroni',
        ingredients: [
          { name: 'Gin', quantity: '30 ml' },
          { name: 'Vermouth rouge', quantity: '30 ml' },
          { name: 'Campari', quantity: '30 ml' },
        ],
      }),
    )

    expect(result.ingredients).toEqual([
      { name: 'Gin', quantity: '30 ml' },
      { name: 'Vermouth rouge', quantity: '30 ml' },
      { name: 'Campari', quantity: '30 ml' },
    ])
  })

  test('defaults to an empty ingredient list when the field is absent', () => {
    const result = parseImportResponse(JSON.stringify({ type: 'plat', title: 'Soupe' }))

    expect(result.ingredients).toEqual([])
  })
})
