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
  VersionNumber,
} from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'
import { Ai } from '~/system/ai'
import type { Proposal as AiProposal, ImportSource, ImportTmxSettings } from '~/system/ai/types'
import type { AcceptedProposal, Proposal } from './types'

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

// Turn the untrusted AI proposal into branded domain shapes. tmxSteps are only
// kept on a tmx recipe and are realigned with the steps (dropped if misaligned).
const brandProposal = (type: RecipeType, proposal: AiProposal): BrandedContent => {
  const ingredients = proposal.ingredients.map((i) => ({
    name: IngredientName(i.name),
    quantity: IngredientQuantity(i.quantity),
  }))
  const steps = proposal.steps.map((s) => StepText(s))
  const rawTmx = proposal.tmxSteps ?? []
  const tmxSteps =
    type === 'tmx'
      ? alignedTmxSteps(steps, toTmxSettings(rawTmx.map((s) => (s ? brandLooseTmx(s) : null))))
      : []
  return { ingredients, steps, tmxSteps }
}

export namespace ProposalUseCase {
  // Ask the AI for the next version after an essai. Loads the tried version (and
  // its own note/remarks outcome) by key — recipe + version, two keyed doc reads,
  // no lineage scan — feeds them to the AI, brands the result into domain shapes
  // and returns it stamped with `basedOn = versionNumber`. Nothing is persisted.
  export const fromEssai = async (
    userId: UserId,
    recipeId: RecipeId,
    versionNumber: VersionNumber,
  ) => {
    const recipe = await RecipeQuery.byId(userId, recipeId)
    if (recipe === 'not-found') return 'not-found'
    const version = await RecipeQuery.versionBy(recipeId, versionNumber)
    if (version === 'not-found') return 'not-found'
    // The version carries its own outcome; feed it to the AI as the sole essai (or
    // none when it has not been executed yet).
    const trials =
      version.executedAt !== null && version.note !== null && version.remarks !== null
        ? [{ note: version.note, remarks: version.remarks }]
        : []

    const proposal = await Ai.proposeNext({
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
      trials,
    })

    const { ingredients, steps, tmxSteps } = brandProposal(recipe.type, proposal)
    const branded: Proposal = {
      basedOn: version.number,
      changeSummary: proposal.changeSummary,
      rationale: proposal.rationale,
      ingredients,
      steps,
      tmxSteps,
    }
    return branded
  }

  // Analyze an import source (photos, a URL or raw text) into a structured recipe
  // preview. The proposal domain is the sole caller of the import AI; confirming
  // this preview persists a brand-new recipe via `RecipeCommand.create` (the recipe
  // domain's `createRecipe` mutation) — nothing is saved here. `_userId` is ignored on
  // purpose: the analysis is globally SHA-cached (keyed on the source, not the caller)
  // and stays user-scoped only from the confirmed `create` onward.
  export const fromPhoto = async (_userId: UserId, source: ImportSource) => Ai.analyzeImport(source)

  // Accept a proposal as an iteration: append version n+1 from the client-supplied
  // content, stamping the version it iterated on (`basedOn`, threaded back through the
  // payload so no lineage rescan is needed).
  export const accept = async (userId: UserId, recipeId: RecipeId, proposal: AcceptedProposal) =>
    RecipeCommand.addVersion(userId, recipeId, {
      change: proposal.changeSummary,
      basedOn: proposal.basedOn,
      ...(proposal.rationale ? { why: proposal.rationale } : {}),
      ingredients: proposal.ingredients,
      steps: proposal.steps,
      tmxSteps: proposal.tmxSteps,
    })
}
