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
export type StepText = Brand<string, 'StepText'>

// A single recipe parameter. An ORDERED list of these (never a map) is the
// canonical shape everywhere — it preserves display order and sidesteps
// Firestore field-path limits on keys with spaces/accents ("Vermouth rouge").
export type Param = { key: ParamKey; value: ParamValue }

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
}
