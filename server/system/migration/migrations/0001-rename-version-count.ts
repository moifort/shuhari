import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'

// The recipe aggregate's version allocator was renamed `versionCount` →
// `lastVersionNumber` (it always was the highest number ever allocated, never a
// count). Recipes stored before the rename still carry the old field while
// `addVersion` reads the new one, so appending a version to them computes
// `undefined + 1` — a NaN the branded `VersionNumber` rejects. Move the field over,
// value untouched; documents already written under the new name are left alone.
export const migration0001: Migration = {
  version: MigrationVersion(1),
  name: MigrationName('rename-version-count'),
  migrate: async ({ db }) => {
    const snapshot = await db.collection('recipes').get()
    let transformed = 0
    for (const doc of snapshot.docs) {
      const { versionCount, ...rest } = doc.data()
      if (versionCount === undefined) continue
      await doc.ref.set({ ...rest, lastVersionNumber: versionCount })
      transformed++
    }
    return { ok: true, transformed }
  },
}
