import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type {
  Ingredient,
  IngredientName,
  IngredientQuantity,
  Note,
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

describe('RecipeCommand.importRecipe', () => {
  test('creates a pointer recipe (no reference yet, v1 to test) and its version atomically', async () => {
    const recipe = await RecipeCommand.importRecipe(userId, newInput(), 'Un site')

    expect(recipe.currentVersion).toBeNull()
    expect(recipe.toTest).toBe(1 as VersionNumber)
    expect(recipe.versionCount).toBe(1 as VersionNumber)
    expect(fake.snapshot('recipes').get(recipe.id as string)?.type).toBe('plat')
    const v1 = fake.snapshot('recipe-versions').get(`${recipe.id}_1`)
    expect(v1?.origin).toEqual({ kind: 'import', detail: 'Un site' })
    // v1 starts as an "essai à faire": no outcome recorded yet.
    expect(v1?.executedAt).toBeNull()
    expect(v1?.note).toBeNull()
    expect(v1?.remarks).toBeNull()
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
      change: 'Bouillon 700 → 650 ml',
      steps: ['Saisir', 'Mijoter'] as StepText[],
      ingredients: [],
      tmxSteps: [null, { speed: 'turbo' as TmxSpeed }],
    })) as Recipe

    expect(withV2.toTest).toBe(2 as VersionNumber)
    expect(withV2.versionCount).toBe(2 as VersionNumber)
    expect(withV2.currentVersion).toBeNull()
    expect(fake.snapshot('recipe-versions').get(`${recipe.id}_2`)?.change).toBe(
      'Bouillon 700 → 650 ml',
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
    // Fresh import: the pending version is v1, so promoting v2 is a no-op.
    const recipe = await RecipeCommand.importRecipe(userId, newInput())
    const result = await RecipeCommand.promote(userId, recipe.id, 2 as VersionNumber)
    expect(result).toBe('nothing-to-test')
  })

  test('returns not-found for an unknown recipe', async () => {
    const result = await RecipeCommand.addVersion(userId, 'nope' as RecipeId, {
      change: 'x',
      steps: [],
      ingredients: [],
      tmxSteps: [],
    })
    expect(result).toBe('not-found')
  })
})

describe('RecipeCommand.recordEssai', () => {
  test('folds the outcome onto v1 and suggests promotion for a high note', async () => {
    const recipe = await RecipeCommand.importRecipe(userId, newInput())
    const batchesBefore = fake.batches.length

    const result = await RecipeCommand.recordEssai(userId, {
      recipeId: recipe.id,
      versionNumber: 1 as VersionNumber,
      note: 5 as Note,
      remarks: 'Parfait' as Remarks,
    })
    if (typeof result === 'string') throw new Error(`expected a result, got ${result}`)

    expect(result.version.note).toBe(5 as Note)
    expect(result.version.remarks).toBe('Parfait' as Remarks)
    expect(result.version.executedAt).toBeInstanceOf(Date)
    // v1 is the pending version, so a note >= PROMOTION_NOTE qualifies it.
    expect(result.promotionSuggested).toBe(true)

    const stored = fake.snapshot('recipe-versions').get(`${recipe.id}_1`)
    expect(stored?.note).toBe(5 as Note)
    expect(stored?.executedAt).toBeInstanceOf(Date)
    // Outcome + recipe bump land in a single batch (all-or-nothing).
    expect(fake.directWrites).toEqual([])
    expect(fake.batches.length).toBe(batchesBefore + 1)
  })

  test('refuses to record a second essai on the same version', async () => {
    const recipe = await RecipeCommand.importRecipe(userId, newInput())
    await RecipeCommand.recordEssai(userId, {
      recipeId: recipe.id,
      versionNumber: 1 as VersionNumber,
      note: 3 as Note,
      remarks: 'Bof' as Remarks,
    })

    const again = await RecipeCommand.recordEssai(userId, {
      recipeId: recipe.id,
      versionNumber: 1 as VersionNumber,
      note: 4 as Note,
      remarks: 'Mieux' as Remarks,
    })
    expect(again).toBe('already-recorded')
  })

  test('returns not-found for an unknown recipe or version', async () => {
    const unknownRecipe = await RecipeCommand.recordEssai(userId, {
      recipeId: 'nope' as RecipeId,
      versionNumber: 1 as VersionNumber,
      note: 4 as Note,
      remarks: '' as Remarks,
    })
    expect(unknownRecipe).toBe('not-found')

    const recipe = await RecipeCommand.importRecipe(userId, newInput())
    const unknownVersion = await RecipeCommand.recordEssai(userId, {
      recipeId: recipe.id,
      versionNumber: 9 as VersionNumber,
      note: 4 as Note,
      remarks: '' as Remarks,
    })
    expect(unknownVersion).toBe('not-found')
  })
})
