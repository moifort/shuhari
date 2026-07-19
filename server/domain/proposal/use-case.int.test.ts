import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { DishContent } from '~/domain/recipe/content/dish'
import type { ThermomixContent } from '~/domain/recipe/content/thermomix'
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
  ThermomixSpeed,
  ThermomixTemperature,
  ThermomixTime,
  VersionNumber,
} from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'
import type { Proposal as AiProposal, ImportAnalysis } from '~/system/ai/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

// The AI is mocked: each test sets `proposal`/`analysis`, and the use-case
// returns it (branded for a proposal, raw for an import analysis).
let proposal: AiProposal
let analysis: ImportAnalysis | 'no-recipe-found'
mock.module('~/system/ai', () => ({
  Ai: {
    proposeNext: async () => proposal,
    analyzeImport: async () => analysis,
  },
}))

const { RecipeCommand } = await import('~/domain/recipe/command')
const { ProposalUseCase } = await import('~/domain/proposal/use-case')

const userId = 'user-1' as UserId
const V1 = 1 as VersionNumber
// The cook that asks for a proposal: it lives in the request until the proposal is
// accepted, never in storage beforehand.
const ATTEMPT = { rating: 3 as Rating, remarks: 'Trop liquide' as Remarks }

// Branded expected values (the fake snapshot is typed to the domain shapes).
const ing = (name: string, quantity: string): Ingredient => ({
  name: name as IngredientName,
  quantity: quantity as IngredientQuantity,
})
const stepList = (...s: string[]) => s.map((x) => x as StepText)
const PROPOSAL_INGREDIENTS = [ing('Veau', '800 g'), ing('Bouillon', '650 ml')]

const dishContent = (): DishContent => ({
  kind: 'dish',
  ingredients: [],
  steps: stepList('Saisir', 'Mijoter'),
})

const recipeInput = (opts: { type?: 'dish' | 'thermomix' } = {}) => {
  const type = opts.type ?? ('dish' as const)
  const content =
    type === 'thermomix'
      ? ({
          kind: 'thermomix',
          ingredients: [],
          steps: stepList('Saisir', 'Mijoter').map((text) => ({ text, settings: {} })),
        } as ThermomixContent)
      : dishContent()
  return { type, category: 'main' as const, title: 'Blanquette' as RecipeTitle, content }
}

const baseProposal = (): AiProposal => ({
  changeSummary: 'Bouillon 700 → 650 ml',
  rationale: 'Trop liquide',
  ingredients: [
    { name: 'Veau', quantity: '800 g' },
    { name: 'Bouillon', quantity: '650 ml' },
  ],
  steps: [
    { text: 'Saisir', settings: {} },
    { text: 'Mijoter', settings: {} },
  ],
})

const baseAnalysis = (): ImportAnalysis => ({
  type: 'dish',
  category: 'main',
  title: 'Blanquette',
  sourceLabel: 'Grand-mère',
  ingredients: [{ name: 'Veau', quantity: '800 g' }],
  steps: [
    { text: 'Saisir', settings: {} },
    { text: 'Mijoter', settings: {} },
  ],
})

let fake = resetFakeFirestore()
beforeEach(() => {
  fake = resetFakeFirestore()
  proposal = baseProposal()
  analysis = baseAnalysis()
})

describe('ProposalUseCase.fromAttempt', () => {
  test('returns not-found for an unknown recipe', async () => {
    expect(await ProposalUseCase.fromAttempt(userId, 'nope' as RecipeId, V1, ATTEMPT)).toBe(
      'not-found',
    )
  })

  test('returns not-found for an unknown version', async () => {
    const recipe = await RecipeCommand.create(userId, recipeInput())
    if (typeof recipe === 'string') throw new Error('expected a recipe')
    expect(await ProposalUseCase.fromAttempt(userId, recipe.id, 9 as VersionNumber, ATTEMPT)).toBe(
      'not-found',
    )
  })

  test('returns the branded proposal based on the tried version, persisting nothing', async () => {
    const recipe = await RecipeCommand.create(userId, recipeInput())
    if (typeof recipe === 'string') throw new Error('expected a recipe')
    const docReadsBefore = fake.docReads
    const queryReadsBefore = fake.queryReads
    const batchesBefore = fake.batches.length
    const result = await ProposalUseCase.fromAttempt(userId, recipe.id, V1, ATTEMPT)
    if (result === 'not-found') throw new Error('expected a proposal')

    expect(result.basedOn).toBe(V1)
    expect(result.changeSummary).toBe('Bouillon 700 → 650 ml')
    expect(result.rationale).toBe('Trop liquide')
    expect(result.content).toEqual({
      kind: 'dish',
      ingredients: PROPOSAL_INGREDIENTS,
      steps: stepList('Saisir', 'Mijoter'),
    })

    // Two keyed doc reads (the recipe pointer + the cooked version) — the attempt
    // itself comes from the caller, so there is no collection scan, no N+1, and
    // nothing written back.
    expect(fake.docReads - docReadsBefore).toBe(2)
    expect(fake.queryReads - queryReadsBefore).toBe(0)
    expect(fake.batches.length).toBe(batchesBefore)
  })

  test('pairs the steps with settings for a thermomix recipe, plain steps for a dish', async () => {
    proposal = {
      ...baseProposal(),
      steps: [
        { text: 'Saisir', settings: { time: '5 min', temperature: '120°C', speed: '1' } },
        { text: 'Mijoter', settings: {} },
      ],
    }
    const thermomix = await RecipeCommand.create(userId, recipeInput({ type: 'thermomix' }))
    if (typeof thermomix === 'string') throw new Error('expected a recipe')
    const thermomixProposal = await ProposalUseCase.fromAttempt(userId, thermomix.id, V1, ATTEMPT)
    if (thermomixProposal === 'not-found') throw new Error('expected a proposal')
    expect(thermomixProposal.content).toEqual({
      kind: 'thermomix',
      ingredients: PROPOSAL_INGREDIENTS,
      steps: [
        {
          text: 'Saisir' as StepText,
          settings: {
            time: '5 min' as ThermomixTime,
            temperature: '120°C' as ThermomixTemperature,
            speed: '1' as ThermomixSpeed,
          },
        },
        { text: 'Mijoter' as StepText, settings: {} },
      ],
    })

    // Same proposal on a dish recipe: Thermomix settings are dropped entirely.
    const dish = await RecipeCommand.create(userId, recipeInput())
    if (typeof dish === 'string') throw new Error('expected a recipe')
    const dishProposal = await ProposalUseCase.fromAttempt(userId, dish.id, V1, ATTEMPT)
    if (dishProposal === 'not-found') throw new Error('expected a proposal')
    expect(dishProposal.content).toEqual({
      kind: 'dish',
      ingredients: PROPOSAL_INGREDIENTS,
      steps: stepList('Saisir', 'Mijoter'),
    })
  })
})

describe('ProposalUseCase.fromPhoto', () => {
  test('returns the AI import analysis without persisting anything', async () => {
    const batchesBefore = fake.batches.length
    const result = await ProposalUseCase.fromPhoto(userId, { kind: 'text', text: 'Blanquette' })

    expect(result).toEqual(baseAnalysis())
    expect(fake.batches.length).toBe(batchesBefore)
  })

  test('passes the no-recipe-found sentinel straight through', async () => {
    analysis = 'no-recipe-found'
    expect(await ProposalUseCase.fromPhoto(userId, { kind: 'text', text: 'nope' })).toBe(
      'no-recipe-found',
    )
  })
})

describe('ProposalUseCase.accept', () => {
  test('appends version n+1 from the passed proposal, based on the threaded version', async () => {
    const recipe = await RecipeCommand.create(userId, recipeInput())
    if (typeof recipe === 'string') throw new Error('expected a recipe')
    const queryReadsBefore = fake.queryReads

    const result = (await ProposalUseCase.accept(userId, recipe.id, {
      basedOn: V1,
      changeSummary: 'Bouillon 700 → 650 ml',
      rationale: 'Trop liquide',
      attempt: ATTEMPT,
      content: {
        kind: 'dish',
        ingredients: PROPOSAL_INGREDIENTS,
        steps: stepList('Saisir', 'Mijoter'),
      },
    })) as Recipe
    expect(result.versionCount).toBe(2 as VersionNumber)

    const v2 = fake.snapshot('recipe-versions').get(`${recipe.id}_2`)
    expect(v2?.change).toBe('Bouillon 700 → 650 ml')
    expect(v2?.why).toBe('Trop liquide')
    // basedOn is threaded through the payload — no lineage rescan to recover it.
    expect(v2?.basedOn).toBe(1 as VersionNumber)
    expect(v2?.content).toEqual({
      kind: 'dish',
      ingredients: PROPOSAL_INGREDIENTS,
      steps: stepList('Saisir', 'Mijoter'),
    })
    expect(v2?.origin).toEqual({ kind: 'ai-proposal' })
    expect(fake.queryReads - queryReadsBefore).toBe(0)
  })

  test('returns not-found for an unknown recipe', async () => {
    expect(
      await ProposalUseCase.accept(userId, 'nope' as RecipeId, {
        basedOn: V1,
        changeSummary: 'x',
        rationale: 'y',
        attempt: ATTEMPT,
        content: { kind: 'dish', ingredients: PROPOSAL_INGREDIENTS, steps: stepList('Saisir') },
      }),
    ).toBe('not-found')
  })
})
