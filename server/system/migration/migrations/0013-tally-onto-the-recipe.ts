import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'

// A library row now reads its best rating, its version count and its to-test count
// off the recipe document instead of loading the lineage of every row on the page.
// Until each stored recipe carries the three, the rows would show no rating and a
// count of nothing.
//
// The rule is spelled out here rather than imported: a migration states what was
// applied on the day it ran, and must not change meaning when the domain rule
// evolves. Its twin lives in `recipe/business-rules.ts` (`tally`).
export const migration0013: Migration = {
  version: MigrationVersion(13),
  name: MigrationName('tally-onto-the-recipe'),
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
      // Keyed on the stored `id` field, which is what a version's `recipeId` points at.
      const tally = tallyOf(lineages.get(data.id) ?? [])
      if (
        data.bestRating === tally.bestRating &&
        data.versionCount === tally.versionCount &&
        data.toTestCount === tally.toTestCount
      )
        continue
      // A full set: a recipe whose versions were never rated loses a stale best
      // rating rather than keeping it — absence is how "never cooked" is spelled.
      const { bestRating: _stale, ...rest } = data
      await doc.ref.set({ ...rest, ...tally })
      transformed++
    }
    return { ok: true, transformed }
  },
}

type StoredVersion = { recipeId: string; rating?: number; toTest?: boolean }

// The best rating across the lineage (absent when nothing was rated), how many
// versions it holds, and how many still owe a try.
const tallyOf = (lineage: StoredVersion[]) => {
  const ratings = lineage
    .map(({ rating }) => rating)
    .filter((rating): rating is number => typeof rating === 'number')
  return {
    ...(ratings.length > 0 ? { bestRating: Math.max(...ratings) } : {}),
    versionCount: lineage.length,
    toTestCount: lineage.filter(({ toTest }) => toTest === true).length,
  }
}
