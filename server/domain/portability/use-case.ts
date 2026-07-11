import { z } from 'zod'
import {
  EXPORT_SCHEMA_VERSION,
  type ExportEnvelope,
  type ImportResult,
} from '~/domain/portability/types'
import { RecipeCommand } from '~/domain/recipe/command'
import { RecipeQuery } from '~/domain/recipe/query'
import type { Recipe, RecipeVersion } from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'
import { TrialCommand } from '~/domain/trial/command'
import { TrialQuery } from '~/domain/trial/query'
import type { Trial } from '~/domain/trial/types'

// Backup/restore orchestrator: reads and replaces each domain's data through its
// public Query/Command surface (raw records) — never its repository.
export namespace PortabilityUseCase {
  export const exportAll = async (userId: UserId): Promise<ExportEnvelope> => {
    const [recipes, versions, trials] = await Promise.all([
      RecipeQuery.all(userId),
      RecipeQuery.allVersions(userId),
      TrialQuery.all(userId),
    ])
    return {
      schemaVersion: EXPORT_SCHEMA_VERSION,
      exportedAt: new Date(),
      userId,
      recipes,
      versions,
      trials,
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
    const trials = stamp(envelope.trials) as unknown as Trial[]

    await RecipeCommand.replaceAllForUser(userId, recipes, versions)
    await TrialCommand.replaceAllForUser(userId, trials)

    return { recipes: recipes.length, versions: versions.length, trials: trials.length }
  }
}

const looseRecord = z.looseObject({ userId: z.string() })

const envelopeSchema = z.object({
  schemaVersion: z.number(),
  exportedAt: z.union([z.string(), z.number(), z.date()]),
  userId: z.string(),
  recipes: z.array(looseRecord),
  versions: z.array(looseRecord),
  trials: z.array(looseRecord),
})
