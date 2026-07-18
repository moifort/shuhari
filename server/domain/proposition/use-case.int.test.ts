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
import type { Proposition as AiProposition, ImportAnalysis } from '~/system/ai/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

// The AI is mocked: each test sets `proposition`/`analysis`, and the use-case
// returns it (branded for a proposition, raw for an import analysis).
let proposition: AiProposition
let analysis: ImportAnalysis | 'no-recipe-found'
mock.module('~/system/ai', () => ({
  Ai: {
    proposeNext: async () => proposition,
    analyzeImport: async () => analysis,
  },
}))

const { RecipeCommand } = await import('~/domain/recipe/command')
const { PropositionUseCase } = await import('~/domain/proposition/use-case')

const userId = 'user-1' as UserId
const V1 = 1 as VersionNumber

// Branded expected values (the fake snapshot is typed to the domain shapes).
const ing = (name: string, quantity: string): Ingredient => ({
  name: name as IngredientName,
  quantity: quantity as IngredientQuantity,
})
const stepList = (...s: string[]) => s.map((x) => x as StepText)
const PROPOSITION_INGREDIENTS = [ing('Veau', '800 g'), ing('Bouillon', '650 ml')]

const recipeInput = (opts: { type?: 'plat' | 'tmx'; subtitle?: RecipeSubtitle } = {}) => ({
  type: opts.type ?? ('plat' as const),
  category: 'plat' as const,
  title: 'Blanquette' as RecipeTitle,
  ...(opts.subtitle ? { subtitle: opts.subtitle } : {}),
  steps: ['Saisir', 'Mijoter'] as StepText[],
  ingredients: [],
  tmxSteps: [] as (TmxSettings | null)[],
})

const baseProposition = (): AiProposition => ({
  changeSummary: 'Bouillon 700 → 650 ml',
  rationale: 'Trop liquide',
  ingredients: [
    { name: 'Veau', quantity: '800 g' },
    { name: 'Bouillon', quantity: '650 ml' },
  ],
  steps: ['Saisir', 'Mijoter'],
  tmxSteps: null,
})

const baseAnalysis = (): ImportAnalysis => ({
  type: 'plat',
  category: 'plat',
  title: 'Blanquette',
  subtitle: null,
  sourceLabel: 'Grand-mère',
  ingredients: [{ name: 'Veau', quantity: '800 g' }],
  steps: ['Saisir', 'Mijoter'],
  tmxSteps: null,
})

let fake = resetFakeFirestore()
beforeEach(() => {
  fake = resetFakeFirestore()
  proposition = baseProposition()
  analysis = baseAnalysis()
})

describe('PropositionUseCase.fromEssai', () => {
  test('returns not-found for an unknown recipe', async () => {
    expect(await PropositionUseCase.fromEssai(userId, 'nope' as RecipeId, V1)).toBe('not-found')
  })

  test('returns not-found for an unknown version', async () => {
    const recipe = await RecipeCommand.create(userId, recipeInput())
    expect(await PropositionUseCase.fromEssai(userId, recipe.id, 9 as VersionNumber)).toBe(
      'not-found',
    )
  })

  test('returns the branded proposition based on the tried version, persisting nothing', async () => {
    const recipe = await RecipeCommand.create(userId, recipeInput())
    const docReadsBefore = fake.docReads
    const queryReadsBefore = fake.queryReads
    const batchesBefore = fake.batches.length
    const result = await PropositionUseCase.fromEssai(userId, recipe.id, V1)
    if (result === 'not-found') throw new Error('expected a proposition')

    expect(result.basedOn).toBe(V1)
    expect(result.changeSummary).toBe('Bouillon 700 → 650 ml')
    expect(result.rationale).toBe('Trop liquide')
    expect(result.ingredients).toEqual(PROPOSITION_INGREDIENTS)
    expect(result.steps).toEqual(stepList('Saisir', 'Mijoter'))

    // Two keyed doc reads (the recipe pointer + the tried version, whose own outcome
    // feeds the AI) — no collection scan, no N+1, nothing written back.
    expect(fake.docReads - docReadsBefore).toBe(2)
    expect(fake.queryReads - queryReadsBefore).toBe(0)
    expect(fake.batches.length).toBe(batchesBefore)
  })

  test('aligns tmxSteps with the steps for a tmx recipe, [] for a plat recipe', async () => {
    proposition = {
      ...baseProposition(),
      tmxSteps: [{ time: '5 min', temperature: '120°C', speed: '1', reverse: null }, null],
    }
    const tmx = await RecipeCommand.create(userId, recipeInput({ type: 'tmx' }))
    const tmxProposition = await PropositionUseCase.fromEssai(userId, tmx.id, V1)
    if (tmxProposition === 'not-found') throw new Error('expected a proposition')
    expect(tmxProposition.tmxSteps).toEqual([
      { time: '5 min' as TmxTime, temperature: '120°C' as TmxTemperature, speed: '1' as TmxSpeed },
      null,
    ])

    // Same proposition on a plat recipe: Thermomix settings are dropped entirely.
    const plat = await RecipeCommand.create(userId, recipeInput())
    const platProposition = await PropositionUseCase.fromEssai(userId, plat.id, V1)
    if (platProposition === 'not-found') throw new Error('expected a proposition')
    expect(platProposition.tmxSteps).toEqual([])
  })
})

describe('PropositionUseCase.fromPhoto', () => {
  test('returns the AI import analysis without persisting anything', async () => {
    const batchesBefore = fake.batches.length
    const result = await PropositionUseCase.fromPhoto(userId, { kind: 'text', text: 'Blanquette' })

    expect(result).toEqual(baseAnalysis())
    expect(fake.batches.length).toBe(batchesBefore)
  })

  test('passes the no-recipe-found sentinel straight through', async () => {
    analysis = 'no-recipe-found'
    expect(await PropositionUseCase.fromPhoto(userId, { kind: 'text', text: 'nope' })).toBe(
      'no-recipe-found',
    )
  })
})

describe('PropositionUseCase.accept', () => {
  test('appends version n+1 from the passed proposition, based on the threaded version', async () => {
    const recipe = await RecipeCommand.create(userId, recipeInput())
    const queryReadsBefore = fake.queryReads

    const result = (await PropositionUseCase.accept(userId, recipe.id, {
      basedOn: V1,
      changeSummary: 'Bouillon 700 → 650 ml',
      rationale: 'Trop liquide',
      ingredients: PROPOSITION_INGREDIENTS,
      steps: stepList('Saisir', 'Mijoter'),
      tmxSteps: [],
    })) as Recipe
    expect(result.versionCount).toBe(2 as VersionNumber)

    const v2 = fake.snapshot('recipe-versions').get(`${recipe.id}_2`)
    expect(v2?.change).toBe('Bouillon 700 → 650 ml')
    expect(v2?.why).toBe('Trop liquide')
    // basedOn is threaded through the payload — no lineage rescan to recover it.
    expect(v2?.basedOn).toBe(1 as VersionNumber)
    expect(v2?.ingredients).toEqual(PROPOSITION_INGREDIENTS)
    expect(v2?.steps).toEqual(stepList('Saisir', 'Mijoter'))
    expect(v2?.origin).toEqual({ kind: 'ai-proposal' })
    expect(fake.queryReads - queryReadsBefore).toBe(0)
  })

  test('returns not-found for an unknown recipe', async () => {
    expect(
      await PropositionUseCase.accept(userId, 'nope' as RecipeId, {
        basedOn: V1,
        changeSummary: 'x',
        rationale: 'y',
        ingredients: PROPOSITION_INGREDIENTS,
        steps: stepList('Saisir'),
        tmxSteps: [],
      }),
    ).toBe('not-found')
  })
})
