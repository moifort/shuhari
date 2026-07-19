import { RecipeCommand } from '~/domain/recipe/command'
import type { VersionContent } from '~/domain/recipe/content/types'
import { VersionContent as brandVersionContent } from '~/domain/recipe/primitives'
import { RecipeQuery } from '~/domain/recipe/query'
import type { RecipeId, RecipeType, VersionNumber } from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'
import { Ai } from '~/system/ai'
import type {
  Proposal as AiProposal,
  ImportSource,
  ImportStep,
  ProposalContext,
} from '~/system/ai/types'
import type { AcceptedProposal, Proposal } from './types'

// Turn the untrusted AI proposal into branded, discriminated content. A dish keeps
// plain-text steps; a Thermomix recipe keeps each step's settings, paired and
// normalized by the shared `VersionContent` constructor (misaligned or empty
// settings collapse to plain steps).
const brandProposal = (type: RecipeType, proposal: AiProposal): VersionContent =>
  type === 'thermomix'
    ? brandVersionContent({
        kind: 'thermomix',
        ingredients: proposal.ingredients,
        steps: proposal.steps,
      })
    : brandVersionContent({
        kind: 'dish',
        ingredients: proposal.ingredients,
        steps: proposal.steps.map((s) => s.text),
      })

// Rebuild the AI context steps from a stored version's content: a dish exposes
// plain steps (empty settings), a Thermomix recipe its per-step settings.
const contextSteps = (content: VersionContent): ImportStep[] =>
  content.kind === 'thermomix'
    ? content.steps.map((s) => ({ text: s.text as string, settings: s.settings }))
    : content.steps.map((text) => ({ text: text as string, settings: {} }))

export namespace ProposalUseCase {
  // Ask the AI for the next version after an attempt. Loads the tried version (and
  // its own rating/remarks outcome) by key — recipe + version, two keyed doc reads,
  // no lineage scan — feeds them to the AI, brands the result into domain shapes
  // and returns it stamped with `basedOn = versionNumber`. Nothing is persisted.
  export const fromAttempt = async (
    userId: UserId,
    recipeId: RecipeId,
    versionNumber: VersionNumber,
  ) => {
    const recipe = await RecipeQuery.byId(userId, recipeId)
    if (recipe === 'not-found') return 'not-found'
    const version = await RecipeQuery.versionBy(recipeId, versionNumber)
    if (version === 'not-found') return 'not-found'
    // The version carries its own outcome; feed it to the AI as the sole attempt (or
    // none when it has not been executed yet).
    const attempts =
      version.rating !== undefined && version.remarks !== undefined
        ? [{ rating: version.rating, remarks: version.remarks }]
        : []

    const context: ProposalContext = {
      type: recipe.type,
      category: recipe.category,
      currentIngredients: version.content.ingredients.map((i) => ({
        name: i.name as string,
        quantity: i.quantity as string,
      })),
      currentSteps: contextSteps(version.content),
      attempts,
    }
    const proposal = await Ai.proposeNext(context)

    const branded: Proposal = {
      basedOn: version.number,
      changeSummary: proposal.changeSummary,
      rationale: proposal.rationale,
      content: brandProposal(recipe.type, proposal),
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
      content: proposal.content,
    })
}
