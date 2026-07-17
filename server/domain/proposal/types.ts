import type {
  Ingredient,
  RecipeId,
  StepText,
  TmxSettings,
  VersionNumber,
} from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'

// An AI proposal for the next step of a recipe, tied to the version that was
// tested. It carries the FULL draft of version n+1 (ingredients + steps) plus a
// short human summary of what changes — no per-parameter diff. At most one active
// proposal per (recipe, version): accepting or refusing deletes the document.
// Presence == pending.
export type Proposal = {
  userId: UserId
  recipeId: RecipeId
  versionNumber: VersionNumber
  createdAt: Date
  changeSummary: string // human summary of what changes ("Bouillon 700 → 650 ml")
  rationale: string
  ingredients: Ingredient[] // full draft of version n+1
  steps: StepText[]
  tmxSteps: (TmxSettings | null)[]
}
