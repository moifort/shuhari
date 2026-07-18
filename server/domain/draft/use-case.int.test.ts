import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type {
  Ingredient,
  IngredientName,
  IngredientQuantity,
  Recipe,
  RecipeId,
  RecipeSubtitle,
  RecipeTitle,
  StepText,
  TmxSettings,
  TmxSpeed,
  TmxTemperature,
  TmxTime,
  VersionNumber,
} from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'
import type { Draft as AiDraft } from '~/system/ai/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

// The AI is mocked: each test sets `draft`, and forTrial returns it branded.
let draft: AiDraft
mock.module('~/system/ai', () => ({ Ai: { draftNext: async () => draft } }))

const { RecipeCommand } = await import('~/domain/recipe/command')
const { DraftUseCase } = await import('~/domain/draft/use-case')

const userId = 'user-1' as UserId
const V1 = 1 as VersionNumber

// Branded expected values (the fake snapshot is typed to the domain shapes).
const ing = (name: string, quantity: string): Ingredient => ({
  name: name as IngredientName,
  quantity: quantity as IngredientQuantity,
})
const stepList = (...s: string[]) => s.map((x) => x as StepText)
const DRAFT_INGREDIENTS = [ing('Veau', '800 g'), ing('Bouillon', '650 ml')]

const recipeInput = (opts: { type?: 'plat' | 'tmx'; subtitle?: RecipeSubtitle } = {}) => ({
  type: opts.type ?? ('plat' as const),
  category: 'plat' as const,
  title: 'Blanquette' as RecipeTitle,
  ...(opts.subtitle ? { subtitle: opts.subtitle } : {}),
  steps: ['Saisir', 'Mijoter'] as StepText[],
  ingredients: [],
  tmxSteps: [] as (TmxSettings | null)[],
})

const baseDraft = (): AiDraft => ({
  changeSummary: 'Bouillon 700 → 650 ml',
  rationale: 'Trop liquide',
  ingredients: [
    { name: 'Veau', quantity: '800 g' },
    { name: 'Bouillon', quantity: '650 ml' },
  ],
  steps: ['Saisir', 'Mijoter'],
  tmxSteps: null,
})

let fake = resetFakeFirestore()
beforeEach(() => {
  fake = resetFakeFirestore()
  draft = baseDraft()
})

describe('DraftUseCase.forTrial', () => {
  test('returns not-found for an unknown recipe', async () => {
    expect(await DraftUseCase.forTrial(userId, 'nope' as RecipeId)).toBe('not-found')
  })

  test('returns the branded draft for the current version without persisting anything', async () => {
    const recipe = await RecipeCommand.create(userId, recipeInput())
    const readsBefore = fake.reads
    const queryReadsBefore = fake.queryReads
    const batchesBefore = fake.batches.length
    const result = await DraftUseCase.forTrial(userId, recipe.id)
    if (result === 'not-found') throw new Error('expected a draft')

    expect(result.versionNumber).toBe(V1)
    expect(result.changeSummary).toBe('Bouillon 700 → 650 ml')
    expect(result.rationale).toBe('Trop liquide')
    expect(result.ingredients).toEqual(DRAFT_INGREDIENTS)
    expect(result.steps).toEqual(stepList('Saisir', 'Mijoter'))

    // One keyed doc read (the recipe pointer) + one lineage scan to derive the
    // version to open, whose own outcome feeds the AI: no N+1, nothing written back.
    expect(fake.reads - readsBefore).toBe(2)
    expect(fake.queryReads - queryReadsBefore).toBe(1)
    expect(fake.batches.length).toBe(batchesBefore)
  })

  test('aligns tmxSteps with the steps for a tmx recipe, [] for a plat recipe', async () => {
    draft = {
      ...baseDraft(),
      tmxSteps: [{ time: '5 min', temperature: '120°C', speed: '1', reverse: null }, null],
    }
    const tmx = await RecipeCommand.create(userId, recipeInput({ type: 'tmx' }))
    const tmxDraft = await DraftUseCase.forTrial(userId, tmx.id)
    if (tmxDraft === 'not-found') throw new Error('expected a draft')
    expect(tmxDraft.tmxSteps).toEqual([
      { time: '5 min' as TmxTime, temperature: '120°C' as TmxTemperature, speed: '1' as TmxSpeed },
      null,
    ])

    // Same draft on a plat recipe: Thermomix settings are dropped entirely.
    const plat = await RecipeCommand.create(userId, recipeInput())
    const platDraft = await DraftUseCase.forTrial(userId, plat.id)
    if (platDraft === 'not-found') throw new Error('expected a draft')
    expect(platDraft.tmxSteps).toEqual([])
  })
})

describe('DraftUseCase.accept', () => {
  test('appends version n+1 from the passed draft, based on the version to open', async () => {
    const recipe = await RecipeCommand.create(userId, recipeInput())

    const result = (await DraftUseCase.accept(userId, recipe.id, {
      changeSummary: 'Bouillon 700 → 650 ml',
      rationale: 'Trop liquide',
      ingredients: DRAFT_INGREDIENTS,
      steps: stepList('Saisir', 'Mijoter'),
      tmxSteps: [],
    })) as Recipe
    expect(result.versionCount).toBe(2 as VersionNumber)

    const v2 = fake.snapshot('recipe-versions').get(`${recipe.id}_2`)
    expect(v2?.change).toBe('Bouillon 700 → 650 ml')
    expect(v2?.why).toBe('Trop liquide')
    // v1 is the only version, so it is the one the fiche would open on: v2 iterates
    // on it.
    expect(v2?.basedOn).toBe(1 as VersionNumber)
    expect(v2?.ingredients).toEqual(DRAFT_INGREDIENTS)
    expect(v2?.steps).toEqual(stepList('Saisir', 'Mijoter'))
    expect(v2?.origin).toEqual({ kind: 'ai-proposal' })
  })

  test('returns not-found for an unknown recipe', async () => {
    expect(
      await DraftUseCase.accept(userId, 'nope' as RecipeId, {
        changeSummary: 'x',
        rationale: 'y',
        ingredients: DRAFT_INGREDIENTS,
        steps: stepList('Saisir'),
        tmxSteps: [],
      }),
    ).toBe('not-found')
  })
})
