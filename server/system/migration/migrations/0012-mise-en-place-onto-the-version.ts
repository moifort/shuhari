import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'

// A cooked version now carries its mise en place — what is readied before the
// first step — as a total list of its content, `[]` when nothing is. The versions
// stored before the section existed carry no key at all, so each gets the empty
// list: an array is never optional, and a document read without the field would
// spell "none" two ways. Nothing is derived from the steps here: the mise en place
// is the AI's to write, and it writes it the next time the cook asks for an
// iteration — a version the cook never returns to keeps its empty one. A coffee has
// no mise en place, it is left alone.
export const migration0012: Migration = {
  version: MigrationVersion(12),
  name: MigrationName('mise-en-place-onto-the-version'),
  migrate: async ({ db }) => {
    const versions = await db.collection('recipe-versions').get()
    let transformed = 0
    for (const doc of versions.docs) {
      const data = doc.data()
      const { content } = data
      if (content.kind === 'coffee' || content.miseEnPlace !== undefined) continue
      await doc.ref.set({ ...data, content: { ...content, miseEnPlace: [] } })
      transformed++
    }
    return { ok: true, transformed }
  },
}
