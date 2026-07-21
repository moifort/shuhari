import { z } from 'zod'
import { RecipeCommand } from '~/domain/recipe/command'
import { RecipeQuery } from '~/domain/recipe/query'
import type { Recipe, RecipeVersion } from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'
import { EXPORT_SCHEMA_VERSION, type ImportResult } from '~/system/portability/types'

// Backup/restore orchestrator: reads and replaces each domain's data through its
// public Query/Command surface (raw records) — never its repository.
export namespace PortabilityUseCase {
  export const exportAll = async (userId: UserId) => {
    const [recipes, versions] = await Promise.all([
      RecipeQuery.all(userId),
      RecipeQuery.allVersions(userId),
    ])
    return {
      schemaVersion: EXPORT_SCHEMA_VERSION,
      exportedAt: new Date(),
      userId,
      recipes,
      versions,
    }
  }

  export const importAll = async (
    userId: UserId,
    rawJson: string,
  ): Promise<ImportResult | { error: string }> => {
    let parsed: unknown
    try {
      parsed = JSON.parse(rawJson)
    } catch {
      return { error: 'invalid-json' }
    }
    const validation = envelopeSchema.safeParse(parsed)
    if (!validation.success) return { error: 'invalid-schema' }
    const envelope = validation.data
    if (envelope.schemaVersion !== EXPORT_SCHEMA_VERSION) {
      return { error: `unsupported-schema-version:${envelope.schemaVersion}` }
    }

    // Stamp the importing user across every record so an export can be restored
    // under a different account (account migration).
    const stamp = <T extends { userId: string }>(rows: T[]) =>
      rows.map((row) => ({ ...row, userId }))
    const recipes = stamp(envelope.recipes) as unknown as Recipe[]
    const versions = stamp(envelope.versions) as unknown as RecipeVersion[]

    await RecipeCommand.replaceAllForUser(userId, recipes, versions)

    return { recipes: recipes.length, versions: versions.length }
  }
}

// Loose on purpose: a record keeps whatever fields the export carried, so a backup
// written by an older build restores rather than being rejected for a field that
// has since moved. What is NOT optional is the identity each document is keyed on —
// a recipe's `id`, a version's `recipeId` + `number`. Those are not data, they are
// the storage key: without them the restore writes documents under keys like
// `undefined_undefined`, which is a corrupt notebook rather than a failed import.
const recipeRecord = z.looseObject({ userId: z.string(), id: z.string().min(1) })

const versionRecord = z.looseObject({
  userId: z.string(),
  recipeId: z.string().min(1),
  number: z.number().int().positive(),
})

const envelopeSchema = z.object({
  schemaVersion: z.number(),
  exportedAt: z.union([z.string(), z.number(), z.date()]),
  userId: z.string(),
  recipes: z.array(recipeRecord),
  versions: z.array(versionRecord),
})
