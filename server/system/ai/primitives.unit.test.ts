import { describe, expect, test } from 'bun:test'
import { RECIPE_MAX } from '~/domain/recipe/limits'
import {
  IngredientName,
  IngredientQuantity,
  RecipeTitle,
  StepText,
  ThermomixTime,
} from '~/domain/recipe/primitives'
import { parseImportResponse, parseProposalResponse } from '~/system/ai/primitives'
import type { ImportAnalysis } from '~/system/ai/types'

const base = { type: 'thermomix', title: 'Risotto' }

// Unwraps a parse expected to yield an analysis; the union's 'no-recipe-found'
// arm is exercised on its own in the dedicated describe below.
const parsedImport = (payload: object): ImportAnalysis => {
  const result = parseImportResponse(JSON.stringify(payload))
  if (result === 'no-recipe-found') throw new Error('expected an analysis')
  return result
}

describe('parseImportResponse — Thermomix steps', () => {
  test('splits step objects into aligned steps and tmxSteps arrays', () => {
    const result = parsedImport({
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
    })

    expect(result.steps).toEqual(['Mixer les oignons', 'Servir', 'Cuire'])
    // The AI's explicit nulls are normalized away at the parse boundary: an
    // absent setting is an absent key, a plain step an entry with no key at all.
    expect(result.tmxSteps).toEqual([
      { time: '5 s', speed: '5' },
      {},
      { time: '14 min', temperature: '100°C', speed: '1', reverse: true },
    ])
  })

  test('collapses tmxSteps to [] when no step carries a setting', () => {
    const result = parsedImport({
      ...base,
      type: 'dish',
      steps: [{ text: 'Émincer' }, { text: 'Saisir', tmxTime: null, tmxReverse: false }],
    })

    expect(result.steps).toEqual(['Émincer', 'Saisir'])
    expect(result.tmxSteps).toEqual([])
  })

  test('tolerates bare string steps as plain steps', () => {
    const result = parsedImport({ ...base, steps: ['Mixer', 'Servir'] })

    expect(result.steps).toEqual(['Mixer', 'Servir'])
    expect(result.tmxSteps).toEqual([])
  })
})

describe('parseImportResponse — dish category', () => {
  test('parses a valid detected category', () => {
    const result = parsedImport({
      type: 'dish',
      category: 'dessert',
      title: 'Tarte',
      steps: ['Cuire'],
    })

    expect(result.category).toBe('dessert')
  })

  test('falls back to main on an invalid category', () => {
    const result = parsedImport({
      type: 'dish',
      category: 'boisson',
      title: 'Soupe',
      steps: ['Cuire'],
    })

    expect(result.category).toBe('main')
  })

  test('falls back to main when the category is missing', () => {
    const result = parsedImport({ type: 'dish', title: 'Soupe', steps: ['Cuire'] })

    expect(result.category).toBe('main')
  })
})

describe('parseImportResponse — ingredients', () => {
  test('parses the ingredient list with names and quantities', () => {
    const result = parsedImport({
      type: 'dish',
      title: 'Ratatouille',
      ingredients: [
        { name: 'Aubergine', quantity: '2 pièces' },
        { name: 'Poivron rouge', quantity: '1 pièce' },
        { name: 'Courgette', quantity: '2 pièces' },
      ],
    })

    expect(result.ingredients).toEqual([
      { name: 'Aubergine', quantity: '2 pièces' },
      { name: 'Poivron rouge', quantity: '1 pièce' },
      { name: 'Courgette', quantity: '2 pièces' },
    ])
  })

  test('defaults to an empty ingredient list when the field is absent', () => {
    // A lone step keeps this a real recipe (no ingredients + no steps is a miss).
    const result = parsedImport({ type: 'dish', title: 'Soupe', steps: ['Cuire'] })

    expect(result.ingredients).toEqual([])
  })
})

describe('parseImportResponse — clamps oversized AI strings to domain limits', () => {
  test('truncates title, ingredients, steps and thermomix settings', () => {
    const result = parsedImport({
      type: 'thermomix',
      title: 'T'.repeat(500),
      ingredients: [{ name: 'N'.repeat(200), quantity: 'Q'.repeat(200) }],
      steps: [{ text: 'E'.repeat(500), tmxTime: 't'.repeat(50) }],
    })

    expect(result.title.length).toBe(RECIPE_MAX.title)
    expect(result.ingredients[0].name.length).toBe(RECIPE_MAX.ingredientName)
    expect(result.ingredients[0].quantity.length).toBe(RECIPE_MAX.ingredientQuantity)
    expect(result.steps[0].length).toBe(RECIPE_MAX.stepText)
    expect(result.tmxSteps[0]?.time?.length).toBe(RECIPE_MAX.thermomix)

    // Backstop against drift: the clamped values pass the domain constructors,
    // so createRecipe can never 400 on these lengths.
    expect(() => RecipeTitle(result.title)).not.toThrow()
    expect(() => IngredientName(result.ingredients[0].name)).not.toThrow()
    expect(() => IngredientQuantity(result.ingredients[0].quantity)).not.toThrow()
    expect(() => StepText(result.steps[0])).not.toThrow()
    expect(() => ThermomixTime(result.tmxSteps[0]?.time ?? '')).not.toThrow()
  })
})

describe('parseImportResponse — drops blank items instead of failing', () => {
  test('drops ingredients/steps whose required fields came back blank', () => {
    const result = parsedImport({
      type: 'thermomix',
      title: 'Risotto',
      ingredients: [
        { name: 'Gin', quantity: '30 ml' },
        { name: '   ', quantity: 'x' },
      ],
      steps: [{ text: 'Mixer', tmxTime: '5 s' }, { text: '   ' }, { text: 'Servir' }],
    })

    expect(result.ingredients).toEqual([{ name: 'Gin', quantity: '30 ml' }])
    // Blank step dropped; tmxSteps stays aligned with the surviving steps.
    expect(result.steps).toEqual(['Mixer', 'Servir'])
    expect(result.tmxSteps).toEqual([{ time: '5 s' }, {}])
  })

  test('drops items whose required field is absent or null instead of throwing', () => {
    const result = parsedImport({
      type: 'dish',
      title: 'Soupe',
      ingredients: [{ name: 'Eau', quantity: '1 L' }, { quantity: '2' }, { name: null }],
      steps: [{ tmxTime: '5 s' }, 'Servir'],
    })

    expect(result.ingredients).toEqual([{ name: 'Eau', quantity: '1 L' }])
    expect(result.steps).toEqual(['Servir'])
  })

  test('falls back to a default title when the AI returns a blank or null one', () => {
    // A step keeps each payload a real recipe so the title fallback is reached.
    expect(parsedImport({ type: 'dish', title: '   ', steps: ['Cuire'] }).title).toBe(
      'Recette importée',
    )
    expect(parsedImport({ type: 'dish', title: null, steps: ['Cuire'] }).title).toBe(
      'Recette importée',
    )
    expect(parsedImport({ type: 'dish', steps: ['Cuire'] }).title).toBe('Recette importée')
  })

  test('caps runaway arrays at 100 items', () => {
    const many = Array.from({ length: 150 }, (_, i) => ({ name: `Ing ${i}`, quantity: '1' }))
    const result = parsedImport({ type: 'dish', title: 'Big recipe', ingredients: many })

    expect(result.ingredients).toHaveLength(100)
  })
})

describe('parseImportResponse — no recipe found', () => {
  test('returns the sentinel when recipeFound is false', () => {
    expect(parseImportResponse(JSON.stringify({ recipeFound: false }))).toBe('no-recipe-found')
  })

  test('returns the sentinel when a found recipe has no ingredients and no steps', () => {
    expect(
      parseImportResponse(JSON.stringify({ recipeFound: true, type: 'dish', title: 'Vide' })),
    ).toBe('no-recipe-found')
  })

  test('parses normally when recipeFound is absent (tolerated) and a recipe is present', () => {
    const result = parsedImport({ type: 'dish', title: 'Soupe', steps: ['Cuire'] })

    expect(result.title).toBe('Soupe')
    expect(result.steps).toEqual(['Cuire'])
  })

  test('parses normally when recipeFound is true and a recipe is present', () => {
    const result = parsedImport({
      recipeFound: true,
      type: 'dish',
      title: 'Ratatouille',
      ingredients: [{ name: 'Aubergine', quantity: '2 pièces' }],
      steps: ['Cuire'],
    })

    expect(result.title).toBe('Ratatouille')
    expect(result.ingredients).toEqual([{ name: 'Aubergine', quantity: '2 pièces' }])
  })
})

describe('parseProposalResponse — full next-version proposal', () => {
  test('parses the change summary, full ingredient/step lists and aligned tmxSteps', () => {
    const result = parseProposalResponse(
      JSON.stringify({
        changeSummary: 'Bouillon 700 → 650 ml',
        rationale: 'Trop liquide',
        ingredients: [
          { name: 'Veau', quantity: '800 g' },
          { name: 'Bouillon', quantity: '650 ml' },
        ],
        steps: [
          { text: 'Saisir', tmxTime: '5 min', tmxTemperature: '120°C', tmxSpeed: '1' },
          { text: 'Mijoter' },
        ],
      }),
    )

    expect(result.changeSummary).toBe('Bouillon 700 → 650 ml')
    expect(result.rationale).toBe('Trop liquide')
    expect(result.ingredients).toEqual([
      { name: 'Veau', quantity: '800 g' },
      { name: 'Bouillon', quantity: '650 ml' },
    ])
    expect(result.steps).toEqual(['Saisir', 'Mijoter'])
    expect(result.tmxSteps).toEqual([{ time: '5 min', temperature: '120°C', speed: '1' }, {}])
  })

  test('clamps the change summary to the domain limit', () => {
    const result = parseProposalResponse(
      JSON.stringify({
        changeSummary: 'C'.repeat(500),
        rationale: 'ok',
        ingredients: [{ name: 'Riz', quantity: '300 g' }],
        steps: ['Cuire'],
      }),
    )

    expect(result.changeSummary.length).toBe(RECIPE_MAX.changeSummary)
  })

  test('drops blank ingredients/steps', () => {
    const result = parseProposalResponse(
      JSON.stringify({
        changeSummary: 'Ajustement',
        rationale: 'ok',
        ingredients: [
          { name: 'Sel', quantity: '5 g' },
          { name: '  ', quantity: 'x' },
        ],
        steps: [{ text: 'Saler' }, { text: '   ' }],
      }),
    )

    expect(result.ingredients).toEqual([{ name: 'Sel', quantity: '5 g' }])
    expect(result.steps).toEqual(['Saler'])
    expect(result.tmxSteps).toEqual([])
  })
})
