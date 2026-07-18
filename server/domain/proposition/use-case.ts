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
import type {
  Proposition as AiProposition,
  ImportSource,
  ImportTmxSettings,
} from '~/system/ai/types'
import type { AcceptedProposition, Proposition } from './types'

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

// Turn the untrusted AI proposition into branded domain shapes. tmxSteps are only
// kept on a tmx recipe and are realigned with the steps (dropped if misaligned).
const brandProposition = (type: RecipeType, proposition: AiProposition): BrandedContent => {
  const ingredients = proposition.ingredients.map((i) => ({
    name: IngredientName(i.name),
    quantity: IngredientQuantity(i.quantity),
  }))
  const steps = proposition.steps.map((s) => StepText(s))
  const rawTmx = proposition.tmxSteps ?? []
  const tmxSteps =
    type === 'tmx'
      ? alignedTmxSteps(steps, toTmxSettings(rawTmx.map((s) => (s ? brandLooseTmx(s) : null))))
      : []
  return { ingredients, steps, tmxSteps }
}

export namespace PropositionUseCase {
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

    const proposition = await Ai.proposeNext({
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

    const { ingredients, steps, tmxSteps } = brandProposition(recipe.type, proposition)
    const branded: Proposition = {
      basedOn: version.number,
      changeSummary: proposition.changeSummary,
      rationale: proposition.rationale,
      ingredients,
      steps,
      tmxSteps,
    }
    return branded
  }

  // Analyze an import source (photos, a URL or raw text) into a structured recipe
  // preview. The proposition domain is the sole caller of the import AI; confirming
  // this preview persists a brand-new recipe via `RecipeCommand.create` (the recipe
  // domain's `createRecipe` mutation) — nothing is saved here. `_userId` is ignored on
  // purpose: the analysis is globally SHA-cached (keyed on the source, not the caller)
  // and stays user-scoped only from the confirmed `create` onward.
  export const fromPhoto = async (_userId: UserId, source: ImportSource) => Ai.analyzeImport(source)

  // Accept a proposition as an iteration: append version n+1 from the client-supplied
  // content, stamping the version it iterated on (`basedOn`, threaded back through the
  // payload so no lineage rescan is needed).
  export const accept = async (
    userId: UserId,
    recipeId: RecipeId,
    proposition: AcceptedProposition,
  ) =>
    RecipeCommand.addVersion(userId, recipeId, {
      change: proposition.changeSummary,
      basedOn: proposition.basedOn,
      ...(proposition.rationale ? { why: proposition.rationale } : {}),
      ingredients: proposition.ingredients,
      steps: proposition.steps,
      tmxSteps: proposition.tmxSteps,
    })
}
