import type {
  ParamKey,
  ParamValue,
  RecipeId,
  RecipeTitle,
  VersionNumber,
} from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'

export type ProposalRecommendation = 'iteration' | 'variation'

// A single proposed parameter change. `from` is null when the parameter is new.
export type ProposalVar = { key: ParamKey; from: ParamValue | null; to: ParamValue }

export type VariationSuggestion = { title: RecipeTitle; description: string }

// An AI proposal for the next step of a recipe, tied to the version that was
// tested. At most one active proposal per (recipe, version): accepting or
// refusing deletes the document. Presence == pending.
export type Proposal = {
  userId: UserId
  recipeId: RecipeId
  versionNumber: VersionNumber
  createdAt: Date
  vars: ProposalVar[]
  rationale: string
  queued: string[] // deferred leads for future iterations
  recommendation: ProposalRecommendation
  variation?: VariationSuggestion
}
