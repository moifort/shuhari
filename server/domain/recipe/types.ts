import type { Brand } from 'ts-brand'
import type { UserId } from '~/domain/shared/types'

// The culinary experiment domains. Drives colour/icon in the app. `plat` is a
// cooked dish, `tmx` a Thermomix recipe.
export const RECIPE_TYPE_VALUES = ['plat', 'tmx'] as const
export type RecipeType = (typeof RECIPE_TYPE_VALUES)[number]

// The course a dish belongs to. Detected by the AI at import and drives sorting
// in the library (Entrée → Plat → Dessert → Soupe → Sauce → Boulangerie).
export const DISH_CATEGORY_VALUES = [
  'entree',
  'plat',
  'dessert',
  'soupe',
  'sauce',
  'boulangerie',
] as const
export type DishCategory = (typeof DISH_CATEGORY_VALUES)[number]

// How the paginated library is ordered. `updatedAt` honours the requested
// direction; `category` always follows the fixed business rank (see
// `categoryRank`) with `updatedAt` desc as the secondary key.
export type RecipeSort = 'updatedAt' | 'category'
export type SortOrder = 'asc' | 'desc'

export type RecipeId = Brand<string, 'RecipeId'>
export type RecipeTitle = Brand<string, 'RecipeTitle'>
export type RecipeSubtitle = Brand<string, 'RecipeSubtitle'>
export type VersionNumber = Brand<number, 'VersionNumber'>
export type Note = Brand<number, 'Note'> // integer 1..5
export type Remarks = Brand<string, 'Remarks'>
export type IngredientName = Brand<string, 'IngredientName'>
export type IngredientQuantity = Brand<string, 'IngredientQuantity'>
export type StepText = Brand<string, 'StepText'>
export type TmxTime = Brand<string, 'TmxTime'>
export type TmxTemperature = Brand<string, 'TmxTemperature'>
export type TmxSpeed = Brand<string, 'TmxSpeed'>

// A recipe component with its measured quantity ("Gin" → "50 ml", "Beurre" →
// "170 g"). The shopping-list view of the recipe. Ordered list, never a map.
export type Ingredient = { name: IngredientName; quantity: IngredientQuantity }

// Thermomix settings for one step, display-oriented strings (no computation is
// ever done on them — "Varoma" and "pétrin" are valid values, not numbers).
export type TmxSettings = {
  time?: TmxTime // "3 min", "30 s", "1 h 10 min"
  temperature?: TmxTemperature // "100°C", "Varoma"
  speed?: TmxSpeed // "5", "3,5", "pétrin", "mijotage", "turbo"
  reverse?: boolean // sens inverse
}

export type VersionOriginKind = 'import' | 'ai-proposal' | 'manual'
export type VersionOrigin = { kind: VersionOriginKind; detail?: string }

// The aggregate root. A light pointer document: the heavy version data lives in
// the satellite `recipe-versions` collection keyed `${recipeId}_${number}`. The
// recipe carries no reference/pending pointers: the best note and the version to
// open are derived from the lineage (see `bestNote`/`versionToOpen`).
export type Recipe = {
  id: RecipeId
  userId: UserId
  type: RecipeType
  // Aggregate-level identity: the dish category is fixed at import and never
  // changes across versions (unlike the versioned recipe content).
  category: DishCategory
  title: RecipeTitle
  subtitle?: RecipeSubtitle
  versionCount: VersionNumber // highest version number allocated so far
  createdAt: Date
  updatedAt: Date
}

// One entry in a recipe's linear lineage (v1 → v2 → …). Its content and lineage
// (steps/ingredients/tmxSteps/origin/change/basedOn) are immutable, but a version
// *is* an essai: it is an "essai à faire" while `executedAt === null`, then carries
// its outcome (note/remarks/photo). The outcome is overwritable — recording again
// re-cooks the same version in place rather than forcing a new one.
export type RecipeVersion = {
  userId: UserId
  recipeId: RecipeId
  number: VersionNumber
  createdAt: Date
  origin: VersionOrigin
  change: string | null // human summary of what changed ("Bouillon 700 → 650 ml"); null for v1
  // The version this one iterates on — set to the essai it was proposed from
  // (`versionToOpen` at draft time); `null` for the original v1, which iterates on
  // nothing. Drives the "essai en cours" branch of `versionToOpen`.
  basedOn: VersionNumber | null
  why?: string // AI rationale, for proposed versions
  steps: StepText[]
  // The recipe's components with quantities. `[]` when the recipe has nothing
  // measurable.
  ingredients: Ingredient[]
  // Thermomix settings aligned with `steps` by index (null = plain step). `[]`
  // for non-tmx recipes — "is Thermomix" is derived from `type === 'tmx'`, never
  // from the presence of this array.
  tmxSteps: (TmxSettings | null)[]
  // The essai outcome, written once when the version is executed. All null while
  // the version is still an "essai à faire" (`executedAt === null`).
  executedAt: Date | null
  note: Note | null
  remarks: Remarks | null
  photoPath: string | null // GCS object path; never exposed raw (see photoUrl)
}
