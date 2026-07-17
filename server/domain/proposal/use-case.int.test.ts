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
import type { ProposalDraft } from '~/system/ai/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

// The AI is mocked: each test sets `draft`, and proposeFromTrial returns it.
let draft: ProposalDraft
mock.module('~/system/ai', () => ({ Ai: { proposeNext: async () => draft } }))

const { RecipeCommand } = await import('~/domain/recipe/command')
const { ProposalUseCase } = await import('~/domain/proposal/use-case')
const { ProposalQuery } = await import('~/domain/proposal/query')

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

const baseDraft = (): ProposalDraft => ({
  changeSummary: 'Bouillon 700 → 650 ml',
  rationale: 'Trop liquide',
  ingredients: [
    { name: 'Veau', quantity: '800 g' },
    { name: 'Bouillon', quantity: '650 ml' },
  ],
  steps: ['Saisir', 'Mijoter'],
  tmxSteps: null,
})

// Import a recipe and persist an AI proposal against its current version.
const seedProposal = async (opts: { type?: 'plat' | 'tmx'; subtitle?: RecipeSubtitle } = {}) => {
  const recipe = await RecipeCommand.importRecipe(userId, recipeInput(opts))
  await ProposalUseCase.proposeFromTrial(userId, recipe.id)
  return recipe
}

let fake = resetFakeFirestore()
beforeEach(() => {
  fake = resetFakeFirestore()
  draft = baseDraft()
})

describe('ProposalUseCase.proposeFromTrial', () => {
  test('returns not-found for an unknown recipe', async () => {
    expect(await ProposalUseCase.proposeFromTrial(userId, 'nope' as RecipeId)).toBe('not-found')
  })

  test('persists the branded draft as the active proposal for the current version', async () => {
    const recipe = await seedProposal()
    const proposal = await ProposalQuery.byRef(recipe.id, V1)

    expect(proposal?.changeSummary).toBe('Bouillon 700 → 650 ml')
    expect(proposal?.rationale).toBe('Trop liquide')
    expect(proposal?.ingredients).toEqual(DRAFT_INGREDIENTS)
    expect(proposal?.steps).toEqual(stepList('Saisir', 'Mijoter'))
  })

  test('aligns tmxSteps with the steps for a tmx recipe, [] for a plat recipe', async () => {
    draft = {
      ...baseDraft(),
      tmxSteps: [{ time: '5 min', temperature: '120°C', speed: '1', reverse: null }, null],
    }
    const tmx = await seedProposal({ type: 'tmx' })
    expect((await ProposalQuery.byRef(tmx.id, V1))?.tmxSteps).toEqual([
      { time: '5 min' as TmxTime, temperature: '120°C' as TmxTemperature, speed: '1' as TmxSpeed },
      null,
    ])

    // Same draft on a plat recipe: Thermomix settings are dropped entirely.
    const plat = await seedProposal()
    expect((await ProposalQuery.byRef(plat.id, V1))?.tmxSteps).toEqual([])
  })
})

describe('ProposalUseCase.acceptAsIteration', () => {
  test('appends version n+1 from the persisted draft and discards the proposal', async () => {
    const recipe = await seedProposal()

    const result = (await ProposalUseCase.acceptAsIteration(userId, recipe.id, V1)) as Recipe
    expect(result.toTest).toBe(2 as VersionNumber)

    const v2 = fake.snapshot('recipe-versions').get(`${recipe.id}_2`)
    expect(v2?.change).toBe('Bouillon 700 → 650 ml')
    expect(v2?.why).toBe('Trop liquide')
    expect(v2?.ingredients).toEqual(DRAFT_INGREDIENTS)
    expect(v2?.steps).toEqual(stepList('Saisir', 'Mijoter'))

    // Proposal consumed.
    expect(await ProposalQuery.byRef(recipe.id, V1)).toBeNull()
  })

  test('an editedDraft wins over the persisted draft', async () => {
    const recipe = await seedProposal()

    await ProposalUseCase.acceptAsIteration(userId, recipe.id, V1, {
      ingredients: [{ name: 'Veau' as IngredientName, quantity: '900 g' as IngredientQuantity }],
      steps: ['Rissoler'] as StepText[],
      tmxSteps: [],
    })

    const v2 = fake.snapshot('recipe-versions').get(`${recipe.id}_2`)
    expect(v2?.ingredients).toEqual([ing('Veau', '900 g')])
    expect(v2?.steps).toEqual(stepList('Rissoler'))
    // The change summary still comes from the proposal, not the edit.
    expect(v2?.change).toBe('Bouillon 700 → 650 ml')
  })

  test('returns no-proposal when there is nothing to accept', async () => {
    const recipe = await RecipeCommand.importRecipe(userId, recipeInput())
    expect(await ProposalUseCase.acceptAsIteration(userId, recipe.id, V1)).toBe('no-proposal')
  })
})
