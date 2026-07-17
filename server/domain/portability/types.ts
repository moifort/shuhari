import type { Recipe, RecipeVersion } from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'

export const EXPORT_SCHEMA_VERSION = 3

export type ExportEnvelope = {
  schemaVersion: number
  exportedAt: Date
  userId: UserId
  recipes: Recipe[]
  versions: RecipeVersion[]
}

export type ImportResult = { recipes: number; versions: number }
