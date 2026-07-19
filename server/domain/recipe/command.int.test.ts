import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type {
  Ingredient,
  IngredientName,
  IngredientQuantity,
  Rating,
  Recipe,
  RecipeId,
  RecipeTitle,
  Remarks,
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
const ingredient = (n: string, q: string): Ingredient => ({
  name: n as IngredientName,
  quantity: q as IngredientQuantity,
})
const newInput = () => ({
  type: 'plat' as const,
  category: 'plat' as const,
  title: 'Blanquette' as RecipeTitle,
  steps: ['Saisir', 'Mijoter'] as StepText[],
  ingredients: [] as Ingredient[],
  tmxSteps: [] as (TmxSettings | null)[],
})

let fake = resetFakeFirestore()
beforeEach(() => {
  fake = resetFakeFirestore()
})

describe('RecipeCommand.create', () => {
  test('creates a pointer recipe and its v1 (basedOn null) atomically', async () => {
    const recipe = await RecipeCommand.create(userId, newInput(), 'Un site')

    expect(recipe.versionCount).toBe(1 as VersionNumber)
    expect(fake.snapshot('recipes').get(recipe.id as string)?.type).toBe('plat')
    const v1 = fake.snapshot('recipe-versions').get(`${recipe.id}_1`)
    expect(v1?.origin).toEqual({ kind: 'import', detail: 'Un site' })
    // v1 iterates on nothing and starts as a planned attempt: no outcome yet.
    expect(v1?.basedOn).toBeNull()
    expect(v1?.executedAt).toBeNull()
    expect(v1?.rating).toBeNull()
    expect(v1?.remarks).toBeNull()
    // Both docs land in a single batch (all-or-nothing).
    expect(fake.directWrites).toEqual([])
    expect(fake.batches.length).toBe(1)
  })

  test('persists per-step Thermomix settings when aligned with the steps', async () => {
    const tmx: TmxSettings = { time: '5 min' as TmxTime, speed: '4' as TmxSpeed, reverse: true }
    const recipe = await RecipeCommand.create(userId, {
      ...newInput(),
      type: 'tmx' as const,
      tmxSteps: [tmx, null],
    })

    expect(fake.snapshot('recipe-versions').get(`${recipe.id}_1`)?.tmxSteps).toEqual([tmx, null])
  })

  test('stores [] tmxSteps when absent or misaligned', async () => {
    const absent = await RecipeCommand.create(userId, newInput())
    expect(fake.snapshot('recipe-versions').get(`${absent.id}_1`)?.tmxSteps).toEqual([])

    const misaligned = await RecipeCommand.create(userId, {
      ...newInput(),
      type: 'tmx' as const,
      tmxSteps: [{ time: '5 min' as TmxTime }],
    })
    expect(fake.snapshot('recipe-versions').get(`${misaligned.id}_1`)?.tmxSteps).toEqual([])

    const notTmx = await RecipeCommand.create(userId, {
      ...newInput(),
      tmxSteps: [{ time: '5 min' as TmxTime }, null],
    })
    expect(fake.snapshot('recipe-versions').get(`${notTmx.id}_1`)?.tmxSteps).toEqual([])
  })

  test('persists ingredients on v1 and stores [] when absent', async () => {
    const ingredients = [ingredient('Gin', '50 ml'), ingredient('Vermouth rouge', '25 ml')]
    const withIngredients = await RecipeCommand.create(userId, { ...newInput(), ingredients })
    expect(fake.snapshot('recipe-versions').get(`${withIngredients.id}_1`)?.ingredients).toEqual(
      ingredients,
    )

    const without = await RecipeCommand.create(userId, newInput())
    expect(fake.snapshot('recipe-versions').get(`${without.id}_1`)?.ingredients).toEqual([])
  })
})

describe('RecipeCommand.addVersion', () => {
  test('appends v2, stamping its basedOn and bumping the version count', async () => {
    const recipe = await RecipeCommand.create(userId, { ...newInput(), type: 'tmx' as const })

    const withV2 = (await RecipeCommand.addVersion(userId, recipe.id, {
      change: 'Bouillon 700 → 650 ml',
      basedOn: 1 as VersionNumber,
      steps: ['Saisir', 'Mijoter'] as StepText[],
      ingredients: [],
      tmxSteps: [null, { speed: 'turbo' as TmxSpeed }],
    })) as Recipe

    expect(withV2.versionCount).toBe(2 as VersionNumber)
    const v2 = fake.snapshot('recipe-versions').get(`${recipe.id}_2`)
    expect(v2?.change).toBe('Bouillon 700 → 650 ml')
    expect(v2?.basedOn).toBe(1 as VersionNumber)
    expect(v2?.executedAt).toBeNull()
    expect(v2?.tmxSteps).toEqual([null, { speed: 'turbo' }])
    // The version + recipe bump land in a single batch (all-or-nothing).
    expect(fake.directWrites).toEqual([])
  })

  test('returns not-found for an unknown recipe', async () => {
    const result = await RecipeCommand.addVersion(userId, 'nope' as RecipeId, {
      change: 'x',
      basedOn: null,
      steps: [],
      ingredients: [],
      tmxSteps: [],
    })
    expect(result).toBe('not-found')
  })
})

describe('RecipeCommand.recordAttempt', () => {
  test('folds the outcome onto v1 and returns the executed version', async () => {
    const recipe = await RecipeCommand.create(userId, newInput())
    const batchesBefore = fake.batches.length

    const result = await RecipeCommand.recordAttempt(userId, {
      recipeId: recipe.id,
      versionNumber: 1 as VersionNumber,
      rating: 5 as Rating,
      remarks: 'Parfait' as Remarks,
    })
    if (typeof result === 'string') throw new Error(`expected a result, got ${result}`)

    expect(result.rating).toBe(5 as Rating)
    expect(result.remarks).toBe('Parfait' as Remarks)
    expect(result.executedAt).toBeInstanceOf(Date)

    const stored = fake.snapshot('recipe-versions').get(`${recipe.id}_1`)
    expect(stored?.rating).toBe(5 as Rating)
    expect(stored?.executedAt).toBeInstanceOf(Date)
    // Outcome + recipe bump land in a single batch (all-or-nothing).
    expect(fake.directWrites).toEqual([])
    expect(fake.batches.length).toBe(batchesBefore + 1)
  })

  test('overwrites a previously recorded attempt on the same version', async () => {
    const recipe = await RecipeCommand.create(userId, newInput())
    await RecipeCommand.recordAttempt(userId, {
      recipeId: recipe.id,
      versionNumber: 1 as VersionNumber,
      rating: 3 as Rating,
      remarks: 'Bof' as Remarks,
    })

    const again = await RecipeCommand.recordAttempt(userId, {
      recipeId: recipe.id,
      versionNumber: 1 as VersionNumber,
      rating: 4 as Rating,
      remarks: 'Mieux' as Remarks,
    })
    if (typeof again === 'string') throw new Error(`expected a result, got ${again}`)
    expect(again.rating).toBe(4 as Rating)
    expect(again.remarks).toBe('Mieux' as Remarks)

    const stored = fake.snapshot('recipe-versions').get(`${recipe.id}_1`)
    expect(stored?.rating).toBe(4 as Rating)
    expect(stored?.remarks).toBe('Mieux' as Remarks)
  })

  test('returns not-found for an unknown recipe or version', async () => {
    const unknownRecipe = await RecipeCommand.recordAttempt(userId, {
      recipeId: 'nope' as RecipeId,
      versionNumber: 1 as VersionNumber,
      rating: 4 as Rating,
      remarks: '' as Remarks,
    })
    expect(unknownRecipe).toBe('not-found')

    const recipe = await RecipeCommand.create(userId, newInput())
    const unknownVersion = await RecipeCommand.recordAttempt(userId, {
      recipeId: recipe.id,
      versionNumber: 9 as VersionNumber,
      rating: 4 as Rating,
      remarks: '' as Remarks,
    })
    expect(unknownVersion).toBe('not-found')
  })
})
