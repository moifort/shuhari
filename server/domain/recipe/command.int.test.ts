import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type {
  Ingredient,
  IngredientName,
  IngredientQuantity,
  Param,
  ParamKey,
  ParamValue,
  Recipe,
  RecipeId,
  RecipeTitle,
  StepText,
  TmxSettings,
  TmxSpeed,
  TmxTime,
  VersionNumber,
} from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { RecipeCommand } = await import('~/domain/recipe/command')

const userId = 'user-1' as UserId
const param = (k: string, v: string): Param => ({ key: k as ParamKey, value: v as ParamValue })
const ingredient = (n: string, q: string): Ingredient => ({
  name: n as IngredientName,
  quantity: q as IngredientQuantity,
})
const newInput = () => ({
  type: 'cafe' as const,
  title: 'Espresso' as RecipeTitle,
  params: [param('Dose', '18 g'), param('Température', '93 °C')],
  steps: ['Moudre', 'Extraire'] as StepText[],
  ingredients: [] as Ingredient[],
  tmxSteps: [] as (TmxSettings | null)[],
})

let fake = resetFakeFirestore()
beforeEach(() => {
  fake = resetFakeFirestore()
})

describe('RecipeCommand.importRecipe', () => {
  test('creates a pointer recipe (v1 current, nothing to test) and its version atomically', async () => {
    const recipe = await RecipeCommand.importRecipe(userId, newInput(), 'Un site')

    expect(recipe.currentVersion).toBe(1 as VersionNumber)
    expect(recipe.toTest).toBeNull()
    expect(recipe.versionCount).toBe(1 as VersionNumber)
    expect(fake.snapshot('recipes').get(recipe.id as string)?.type).toBe('cafe')
    expect(fake.snapshot('recipe-versions').get(`${recipe.id}_1`)?.origin).toEqual({
      kind: 'import',
      detail: 'Un site',
    })
    // Both docs land in a single batch (all-or-nothing).
    expect(fake.directWrites).toEqual([])
    expect(fake.batches.length).toBe(1)
  })

  test('persists per-step Thermomix settings when aligned with the steps', async () => {
    const tmx: TmxSettings = { time: '5 min' as TmxTime, speed: '4' as TmxSpeed, reverse: true }
    const recipe = await RecipeCommand.importRecipe(userId, {
      ...newInput(),
      type: 'tmx' as const,
      tmxSteps: [tmx, null],
    })

    expect(fake.snapshot('recipe-versions').get(`${recipe.id}_1`)?.tmxSteps).toEqual([tmx, null])
  })

  test('stores [] tmxSteps when absent or misaligned', async () => {
    const absent = await RecipeCommand.importRecipe(userId, newInput())
    expect(fake.snapshot('recipe-versions').get(`${absent.id}_1`)?.tmxSteps).toEqual([])

    const misaligned = await RecipeCommand.importRecipe(userId, {
      ...newInput(),
      type: 'tmx' as const,
      tmxSteps: [{ time: '5 min' as TmxTime }],
    })
    expect(fake.snapshot('recipe-versions').get(`${misaligned.id}_1`)?.tmxSteps).toEqual([])

    const notTmx = await RecipeCommand.importRecipe(userId, {
      ...newInput(),
      tmxSteps: [{ time: '5 min' as TmxTime }, null],
    })
    expect(fake.snapshot('recipe-versions').get(`${notTmx.id}_1`)?.tmxSteps).toEqual([])
  })

  test('persists ingredients on v1 and stores [] when absent', async () => {
    const ingredients = [ingredient('Gin', '50 ml'), ingredient('Vermouth rouge', '25 ml')]
    const withIngredients = await RecipeCommand.importRecipe(userId, { ...newInput(), ingredients })
    expect(fake.snapshot('recipe-versions').get(`${withIngredients.id}_1`)?.ingredients).toEqual(
      ingredients,
    )

    const without = await RecipeCommand.importRecipe(userId, newInput())
    expect(fake.snapshot('recipe-versions').get(`${without.id}_1`)?.ingredients).toEqual([])
  })
})

describe('RecipeCommand.addVersion + promote', () => {
  test('appends v2 as toTest, then promotes it to the current reference', async () => {
    const recipe = await RecipeCommand.importRecipe(userId, { ...newInput(), type: 'tmx' as const })

    const withV2 = (await RecipeCommand.addVersion(userId, recipe.id, {
      change: 'Température 93 → 92 °C',
      changedKeys: ['Température' as ParamKey],
      params: [param('Dose', '18 g'), param('Température', '92 °C')],
      steps: ['Moudre', 'Extraire'] as StepText[],
      ingredients: [],
      tmxSteps: [null, { speed: 'turbo' as TmxSpeed }],
    })) as Recipe

    expect(withV2.toTest).toBe(2 as VersionNumber)
    expect(withV2.versionCount).toBe(2 as VersionNumber)
    expect(withV2.currentVersion).toBe(1 as VersionNumber)
    expect(fake.snapshot('recipe-versions').get(`${recipe.id}_2`)?.change).toBe(
      'Température 93 → 92 °C',
    )
    expect(fake.snapshot('recipe-versions').get(`${recipe.id}_2`)?.tmxSteps).toEqual([
      null,
      { speed: 'turbo' },
    ])

    const promoted = (await RecipeCommand.promote(userId, recipe.id, 2 as VersionNumber)) as Recipe
    expect(promoted.currentVersion).toBe(2 as VersionNumber)
    expect(promoted.toTest).toBeNull()
  })

  test('refuses to promote a version that is not the pending one', async () => {
    const recipe = await RecipeCommand.importRecipe(userId, newInput())
    const result = await RecipeCommand.promote(userId, recipe.id, 1 as VersionNumber)
    expect(result).toBe('nothing-to-test')
  })

  test('returns not-found for an unknown recipe', async () => {
    const result = await RecipeCommand.addVersion(userId, 'nope' as RecipeId, {
      change: 'x',
      changedKeys: [],
      params: [],
      steps: [],
      ingredients: [],
      tmxSteps: [],
    })
    expect(result).toBe('not-found')
  })
})
