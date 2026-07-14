import type { Brand } from 'ts-brand'
import type { UserId } from '~/domain/shared/types'

// The four experiment domains. Drives colour/icon in the app and — critically —
// the number of variables the AI may change per iteration (see proposal domain).
export const RECIPE_TYPE_VALUES = ['cafe', 'cocktail', 'plat', 'tmx'] as const
export type RecipeType = (typeof RECIPE_TYPE_VALUES)[number]

export type RecipeId = Brand<string, 'RecipeId'>
export type RecipeTitle = Brand<string, 'RecipeTitle'>
export type RecipeSubtitle = Brand<string, 'RecipeSubtitle'>
export type VersionNumber = Brand<number, 'VersionNumber'>
export type ParamKey = Brand<string, 'ParamKey'>
export type ParamValue = Brand<string, 'ParamValue'>
export type IngredientName = Brand<string, 'IngredientName'>
export type IngredientQuantity = Brand<string, 'IngredientQuantity'>
export type StepText = Brand<string, 'StepText'>
export type TmxTime = Brand<string, 'TmxTime'>
export type TmxTemperature = Brand<string, 'TmxTemperature'>
export type TmxSpeed = Brand<string, 'TmxSpeed'>

// A single recipe parameter. An ORDERED list of these (never a map) is the
// canonical shape everywhere — it preserves display order and sidesteps
// Firestore field-path limits on keys with spaces/accents ("Vermouth rouge").
export type Param = { key: ParamKey; value: ParamValue }

// A recipe component with its measured quantity ("Gin" → "50 ml", "Beurre" →
// "170 g"). The shopping-list view of the recipe — distinct from `params`, which
// are the reproducibility knobs the AI iterates on. Ordered list, never a map.
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
// the append-only `recipe-versions` collection keyed `${recipeId}_${number}`.
export type Recipe = {
  id: RecipeId
  userId: UserId
  type: RecipeType
  title: RecipeTitle
  subtitle?: RecipeSubtitle
  currentVersion: VersionNumber // the reproducible reference
  toTest: VersionNumber | null // the version awaiting a trial, if any
  versionCount: VersionNumber // highest version number allocated so far
  derivedFrom: RecipeId | null // parent recipe when this is a variation
  createdAt: Date
  updatedAt: Date
}

// An immutable entry in a recipe's linear lineage (v1 → v2 → …).
export type RecipeVersion = {
  userId: UserId
  recipeId: RecipeId
  number: VersionNumber
  createdAt: Date
  origin: VersionOrigin
  change: string | null // human diff text ("Température 93 → 92 °C"); null for v1
  changedKeys: ParamKey[] // params touched by this version (for highlighting)
  why?: string // AI rationale, for proposed versions
  params: Param[] // the TARGET parameters
  steps: StepText[]
  // The recipe's components with quantities. Additive — carried forward across
  // iterations, but not yet an AI-iteration target. `[]` when the recipe has
  // nothing measurable.
  ingredients: Ingredient[]
  // Thermomix settings aligned with `steps` by index (null = plain step). `[]`
  // for non-tmx recipes — "is Thermomix" is derived from `type === 'tmx'`, never
  // from the presence of this array.
  tmxSteps: (TmxSettings | null)[]
}
