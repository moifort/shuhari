import type { Brand } from 'ts-brand'
import type { UserId } from '~/domain/shared/types'

// The culinary experiment domains. Drives colour/icon in the app. `dish` is a
// cooked dish, `thermomix` a Thermomix recipe.
export const RECIPE_TYPE_VALUES = ['dish', 'thermomix'] as const
export type RecipeType = (typeof RECIPE_TYPE_VALUES)[number]

// The course a dish belongs to. Detected by the AI at import and drives sorting
// in the library (starter → main → dessert → soup → sauce → baking → drink). The
// array order IS the business rank — see `categoryRank`.
export const DISH_CATEGORY_VALUES = [
  'starter',
  'main',
  'dessert',
  'soup',
  'sauce',
  'baking',
  'drink',
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
export type ThermomixTime = Brand<string, 'ThermomixTime'>
export type ThermomixTemperature = Brand<string, 'ThermomixTemperature'>
export type ThermomixSpeed = Brand<string, 'ThermomixSpeed'>

// A recipe component with its measured quantity ("Gin" → "50 ml", "Beurre" →
// "170 g"). The shopping-list view of the recipe. Ordered list, never a map.
export type Ingredient = { name: IngredientName; quantity: IngredientQuantity }

// Thermomix settings for one step, display-oriented strings (no computation is
// ever done on them — "Varoma" and "pétrin" are valid values, not numbers).
// Every field absent (`{}`) means "this step carries no Thermomix setting" — the
// single representation of a plain step inside a `ThermomixStep`.
export type ThermomixSettings = {
  time?: ThermomixTime // "3 min", "30 s", "1 h 10 min"
  temperature?: ThermomixTemperature // "100°C", "Varoma"
  speed?: ThermomixSpeed // "5", "3,5", "pétrin", "mijotage", "turbo"
  reverse?: boolean // reverse rotation
}

export type VersionOriginKind = 'import' | 'ai-proposal' | 'manual'
export type VersionOrigin = { kind: VersionOriginKind; detail?: string }

// The lineage entry lives in its own module (the type-agnostic versioning
// envelope), re-exported here so callers keep a single recipe-domain import.
export type { RecipeVersion } from '~/domain/recipe/version'

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
  // Marked as a favourite by the cook. Aggregate-level like `category`, and absent
  // rather than false when it is not one — the library's favourites lens filters on
  // its presence.
  favorite?: true
  versionCount: VersionNumber // highest version number allocated so far
  createdAt: Date
  updatedAt: Date
}
