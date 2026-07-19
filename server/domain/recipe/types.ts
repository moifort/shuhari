import type { Brand } from 'ts-brand'
import type { UserId } from '~/domain/shared/types'

// The culinary experiment domains. Drives colour/icon in the app. `dish` is a
// cooked dish, `tmx` a Thermomix recipe.
export const RECIPE_TYPE_VALUES = ['dish', 'tmx'] as const
export type RecipeType = (typeof RECIPE_TYPE_VALUES)[number]

// The course a dish belongs to. Detected by the AI at import and drives sorting
// in the library (starter → main → dessert → soup → sauce → baking). The array
// order IS the business rank — see `categoryRank`.
export const DISH_CATEGORY_VALUES = [
  'starter',
  'main',
  'dessert',
  'soup',
  'sauce',
  'baking',
] as const
export type DishCategory = (typeof DISH_CATEGORY_VALUES)[number]

// How the paginated library is ordered. `updatedAt` honours the requested
// direction; `category` always follows the fixed business rank (see
// `categoryRank`) with `updatedAt` desc as the secondary key.
export type RecipeSort = 'updatedAt' | 'category'
export type SortOrder = 'asc' | 'desc'

export type RecipeId = Brand<string, 'RecipeId'>
export type RecipeTitle = Brand<string, 'RecipeTitle'>
export type VersionNumber = Brand<number, 'VersionNumber'>
export type Rating = Brand<number, 'Rating'> // integer 1..5
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
// Every field absent (`{}`) means "this step carries no Thermomix setting" — the
// single representation of a plain step inside the parallel `tmxSteps` array.
export type TmxSettings = {
  time?: TmxTime // "3 min", "30 s", "1 h 10 min"
  temperature?: TmxTemperature // "100°C", "Varoma"
  speed?: TmxSpeed // "5", "3,5", "pétrin", "mijotage", "turbo"
  reverse?: boolean // reverse rotation
}

export type VersionOriginKind = 'import' | 'ai-proposal' | 'manual'
export type VersionOrigin = { kind: VersionOriginKind; detail?: string }

// The aggregate root. A light pointer document: the heavy version data lives in
// the satellite `recipe-versions` collection keyed `${recipeId}_${number}`. The
// recipe carries no reference/pending pointers: the best rating and the version
// to open are derived from the lineage (see `bestRating`/`versionToOpen`).
export type Recipe = {
  id: RecipeId
  userId: UserId
  type: RecipeType
  // Aggregate-level identity: the dish category is fixed at import and never
  // changes across versions (unlike the versioned recipe content).
  category: DishCategory
  title: RecipeTitle
  versionCount: VersionNumber // highest version number allocated so far
  createdAt: Date
  updatedAt: Date
}

// One entry in a recipe's linear lineage (v1 → v2 → …). Its content and lineage
// (steps/ingredients/tmxSteps/origin/change/basedOn) are immutable, but a version
// *is* an attempt: it is a planned attempt while `executedAt` is absent, then carries
// its outcome (rating/remarks/photo). The outcome is overwritable — recording again
// re-cooks the same version in place rather than forcing a new one.
export type RecipeVersion = {
  userId: UserId
  recipeId: RecipeId
  number: VersionNumber
  createdAt: Date
  origin: VersionOrigin
  change?: string // human summary of what changed ("Bouillon 700 → 650 ml"); absent on v1
  // The version this one iterates on — set to the attempt it was proposed from
  // (`versionToOpen` at proposal time); absent on the original v1, which iterates
  // on nothing. Drives the "attempt in progress" branch of `versionToOpen`.
  basedOn?: VersionNumber
  why?: string // AI rationale, for proposed versions
  steps: StepText[]
  // The recipe's components with quantities. `[]` when the recipe has nothing
  // measurable.
  ingredients: Ingredient[]
  // Thermomix settings aligned with `steps` by index (an entry with every field
  // absent — `{}` — = plain step). `[]` for non-tmx recipes — "is Thermomix" is
  // derived from `type === 'tmx'`, never from the presence of this array.
  tmxSteps: TmxSettings[]
  // The attempt outcome, written once when the version is executed. All absent
  // while the version is still a planned attempt (no `executedAt`).
  executedAt?: Date
  rating?: Rating
  remarks?: Remarks
  photoPath?: string // GCS object path; never exposed raw (see photoUrl)
}
