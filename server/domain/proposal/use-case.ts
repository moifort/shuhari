import { ProposalCommand } from '~/domain/proposal/command'
import { ProposalQuery } from '~/domain/proposal/query'
import type { Proposal } from '~/domain/proposal/types'
import {
  alignedTmxSteps,
  type LooseTmxSettings,
  toTmxSettings,
} from '~/domain/recipe/business-rules'
import { RecipeCommand } from '~/domain/recipe/command'
import {
  IngredientName,
  IngredientQuantity,
  RecipeTitle,
  StepText,
  TmxSpeed,
  TmxTemperature,
  TmxTime,
} from '~/domain/recipe/primitives'
import { RecipeQuery } from '~/domain/recipe/query'
import type {
  Ingredient,
  RecipeId,
  RecipeType,
  StepText as StepTextT,
  TmxSettings,
  VersionNumber,
} from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'
import { TrialQuery } from '~/domain/trial/query'
import { Ai } from '~/system/ai'
import type { ImportTmxSettings, ProposalDraft } from '~/system/ai/types'

// The full next-version draft, already validated into branded domain shapes —
// either freshly branded from the AI or the user's inline edits from iOS.
export type EditedDraft = {
  ingredients: Ingredient[]
  steps: StepTextT[]
  tmxSteps: (TmxSettings | null)[]
}

// Brand one step's raw AI tmx settings into the loose (still-nullable) shape the
// shared `toTmxSettings` normalizer expects.
const brandLooseTmx = (raw: ImportTmxSettings): LooseTmxSettings => ({
  time: raw.time ? TmxTime(raw.time) : null,
  temperature: raw.temperature ? TmxTemperature(raw.temperature) : null,
  speed: raw.speed ? TmxSpeed(raw.speed) : null,
  reverse: raw.reverse,
})

// Turn the untrusted AI draft into branded domain shapes. tmxSteps are only kept
// on a tmx recipe and are realigned with the steps (dropped if misaligned).
const brandDraft = (type: RecipeType, draft: ProposalDraft): EditedDraft => {
  const ingredients = draft.ingredients.map((i) => ({
    name: IngredientName(i.name),
    quantity: IngredientQuantity(i.quantity),
  }))
  const steps = draft.steps.map((s) => StepText(s))
  const rawTmx = draft.tmxSteps ?? []
  const tmxSteps =
    type === 'tmx'
      ? alignedTmxSteps(steps, toTmxSettings(rawTmx.map((s) => (s ? brandLooseTmx(s) : null))))
      : []
  return { ingredients, steps, tmxSteps }
}

export namespace ProposalUseCase {
  // Ask the AI for the next step after a trial. Reads the tested version and its
  // trials (note/remarks only), drafts the full next version, and persists it as
  // the single active proposal for that version.
  export const proposeFromTrial = async (userId: UserId, recipeId: RecipeId) => {
    const recipe = await RecipeQuery.byId(userId, recipeId)
    if (recipe === 'not-found') return 'not-found'
    const version = await RecipeQuery.versionBy(recipeId, recipe.currentVersion)
    if (version === 'not-found') return 'not-found'
    const trials = await TrialQuery.byVersion(userId, recipeId, recipe.currentVersion)

    const draft = await Ai.proposeNext({
      type: recipe.type,
      category: recipe.category,
      currentIngredients: version.ingredients.map((i) => ({
        name: i.name as string,
        quantity: i.quantity as string,
      })),
      currentSteps: version.steps.map((s) => s as string),
      currentTmxSteps: version.tmxSteps.map((s) =>
        s
          ? {
              time: s.time ?? null,
              temperature: s.temperature ?? null,
              speed: s.speed ?? null,
              reverse: s.reverse ?? null,
            }
          : null,
      ),
      trials: trials.map((t) => ({ note: t.note, remarks: t.remarks })),
    })

    const { ingredients, steps, tmxSteps } = brandDraft(recipe.type, draft)
    const proposal: Proposal = {
      userId,
      recipeId,
      versionNumber: recipe.currentVersion,
      createdAt: new Date(),
      changeSummary: draft.changeSummary,
      rationale: draft.rationale,
      ingredients,
      steps,
      tmxSteps,
      recommendation: draft.recommendation,
      ...(draft.variation
        ? {
            variation: {
              title: RecipeTitle(draft.variation.title),
              description: draft.variation.description,
            },
          }
        : {}),
    }
    return ProposalCommand.propose(proposal)
  }

  // Accept a proposal as an iteration: append version n+1 from the draft (or the
  // user's inline edits) and mark it "to test".
  export const acceptAsIteration = async (
    userId: UserId,
    recipeId: RecipeId,
    versionNumber: VersionNumber,
    editedDraft?: EditedDraft,
  ) => {
    const proposal = await ProposalQuery.byRef(recipeId, versionNumber)
    if (!proposal) return 'no-proposal'
    const draft = editedDraft ?? proposal
    const result = await RecipeCommand.addVersion(userId, recipeId, {
      change: proposal.changeSummary,
      ...(proposal.rationale ? { why: proposal.rationale } : {}),
      ingredients: draft.ingredients,
      steps: draft.steps,
      tmxSteps: draft.tmxSteps,
    })
    if (result !== 'not-found') await ProposalCommand.discard(recipeId, versionNumber)
    return result
  }

  // Accept a proposal as a variation: a brand-new recipe derived from this one,
  // carrying the draft (or the user's inline edits) as its v1.
  export const acceptAsVariation = async (
    userId: UserId,
    recipeId: RecipeId,
    versionNumber: VersionNumber,
    editedDraft?: EditedDraft,
  ) => {
    const recipe = await RecipeQuery.byId(userId, recipeId)
    if (recipe === 'not-found') return 'not-found'
    const proposal = await ProposalQuery.byRef(recipeId, versionNumber)
    if (!proposal) return 'no-proposal'
    const draft = editedDraft ?? proposal

    const title = proposal.variation?.title ?? recipe.title
    const result = await RecipeCommand.deriveVariation(
      userId,
      recipeId,
      {
        type: recipe.type,
        category: recipe.category,
        title,
        ...(recipe.subtitle ? { subtitle: recipe.subtitle } : {}),
        ingredients: draft.ingredients,
        steps: draft.steps,
        tmxSteps: draft.tmxSteps,
      },
      proposal.changeSummary,
    )
    if (result !== 'not-found') await ProposalCommand.discard(recipeId, versionNumber)
    return result
  }

  export const refuse = async (recipeId: RecipeId, versionNumber: VersionNumber) =>
    ProposalCommand.discard(recipeId, versionNumber)
}
