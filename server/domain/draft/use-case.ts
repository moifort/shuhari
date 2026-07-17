import {
  alignedTmxSteps,
  type LooseTmxSettings,
  toTmxSettings,
} from '~/domain/recipe/business-rules'
import { RecipeCommand } from '~/domain/recipe/command'
import {
  IngredientName,
  IngredientQuantity,
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
} from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'
import { TrialQuery } from '~/domain/trial/query'
import { Ai } from '~/system/ai'
import type { Draft as AiDraft, ImportTmxSettings } from '~/system/ai/types'
import type { AcceptedDraft, Draft } from './types'

// The content-only slice branded from the AI response.
type BrandedContent = {
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
const brandDraft = (type: RecipeType, draft: AiDraft): BrandedContent => {
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

export namespace DraftUseCase {
  // Ask the AI for the next step after a trial. Reads the tested version and its
  // trials (note/remarks only), drafts the full next version, brands it into
  // domain shapes, and returns it — nothing is persisted.
  export const forTrial = async (userId: UserId, recipeId: RecipeId) => {
    const recipe = await RecipeQuery.byId(userId, recipeId)
    if (recipe === 'not-found') return 'not-found'
    const version = await RecipeQuery.versionBy(recipeId, recipe.currentVersion)
    if (version === 'not-found') return 'not-found'
    const trials = await TrialQuery.byVersion(userId, recipeId, recipe.currentVersion)

    const draft = await Ai.draftNext({
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
    const branded: Draft = {
      versionNumber: recipe.currentVersion,
      changeSummary: draft.changeSummary,
      rationale: draft.rationale,
      ingredients,
      steps,
      tmxSteps,
    }
    return branded
  }

  // Accept a draft as an iteration: append version n+1 from the client-supplied
  // draft and mark it "to test".
  export const accept = async (userId: UserId, recipeId: RecipeId, draft: AcceptedDraft) =>
    RecipeCommand.addVersion(userId, recipeId, {
      change: draft.changeSummary,
      ...(draft.rationale ? { why: draft.rationale } : {}),
      ingredients: draft.ingredients,
      steps: draft.steps,
      tmxSteps: draft.tmxSteps,
    })
}
