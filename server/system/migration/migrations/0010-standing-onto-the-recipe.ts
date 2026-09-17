import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'

// The library now ranks a recipe inside its course on `standing` — hearted first,
// then the best rating, never cooked last — and Firestore silently drops from an
// ordered query every document missing the ordered field. Until each stored recipe
// carries one, the course-sorted notebook would open empty.
//
// The rule is spelled out here rather than imported: a migration states what was
// applied on the day it ran, and must not change meaning when the domain rule
// evolves. Its twin lives in `recipe/business-rules.ts` (`standing`).
export const migration0010: Migration = {
  version: MigrationVersion(10),
  name: MigrationName('standing-onto-the-recipe'),
  migrate: async ({ db }) => {
    const [recipes, versions] = await Promise.all([
      db.collection('recipes').get(),
      db.collection('recipe-versions').get(),
    ])
    const lineages = new Map<string, StoredVersion[]>()
    for (const doc of versions.docs) {
      const version = doc.data() as StoredVersion
      const lineage = lineages.get(version.recipeId) ?? []
      lineage.push(version)
      lineages.set(version.recipeId, lineage)
    }

    let transformed = 0
    for (const doc of recipes.docs) {
      const data = doc.data()
      // Keyed on the stored `id` field, which is what a version's `recipeId` points
      // at. A recipe seen without its lineage still gets a standing — the lowest —
      // because leaving the field out is what would take it off the list.
      const standing = standingOf(lineages.get(data.id) ?? [])
      if (data.standing === standing) continue
      await doc.ref.set({ ...data, standing })
      transformed++
    }
    return { ok: true, transformed }
  },
}

type StoredVersion = { recipeId: string; number: number; rating?: number; favorite?: boolean }

const HEARTED_STANDING = 10

// Any hearted version puts the recipe above every rating; otherwise the best rating
// across the lineage decides, and a recipe never cooked stands at 0.
const standingOf = (lineage: StoredVersion[]): number =>
  lineage.some(({ favorite }) => favorite === true)
    ? HEARTED_STANDING
    : Math.max(0, ...lineage.map(({ rating }) => (typeof rating === 'number' ? rating : 0)))
