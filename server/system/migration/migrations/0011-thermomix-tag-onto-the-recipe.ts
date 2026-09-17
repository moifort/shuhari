import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'

// A library row no longer wears its recipe's type: it wears the recipe's tags, and
// a recipe created on the Thermomix is now born tagged "Thermomix". The ones stored
// before tags existed would lose the only mark that told them apart from a plain
// dish, so each gets the tag a new one is born with.
//
// A recipe that already carries tags is left alone — it has been through the new
// code, and what it is filed under is the cook's own doing. The tag is spelled out
// here rather than imported: a migration states what was applied on the day it ran.
// Its twin lives in `recipe/business-rules.ts` (`tagsAtBirth`).
export const migration0011: Migration = {
  version: MigrationVersion(11),
  name: MigrationName('thermomix-tag-onto-the-recipe'),
  migrate: async ({ db }) => {
    const recipes = await db.collection('recipes').where('type', '==', 'thermomix').get()
    let transformed = 0
    for (const doc of recipes.docs) {
      const data = doc.data()
      if (data.tags !== undefined) continue
      await doc.ref.set({ ...data, tags: [{ label: 'Thermomix', icon: 'thermomix' }] })
      transformed++
    }
    return { ok: true, transformed }
  },
}
