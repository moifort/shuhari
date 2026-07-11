import type { Recipe, RecipeVersion } from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'
import type { Trial } from '~/domain/trial/types'

export const EXPORT_SCHEMA_VERSION = 1

export type ExportEnvelope = {
  schemaVersion: number
  exportedAt: Date
  userId: UserId
  recipes: Recipe[]
  versions: RecipeVersion[]
  trials: Trial[]
}

export type ImportResult = { recipes: number; versions: number; trials: number }
