import type { CachedImport, ImportHash } from '~/system/ai/types'
import { db } from '~/system/firebase'
import { genericDataConverter, withoutStoredNulls } from '~/utils/firestore'

// The analysis is stored as-is: every array is total (a plain step is the empty
// settings object `{}`, which Firestore stores verbatim), so no positional
// placeholder is needed and the stored shape IS the domain shape.
const cache = () =>
  db().collection('import-cache').withConverter(genericDataConverter<CachedImport>())

export const findBy = async (importHash: ImportHash): Promise<CachedImport | undefined> => {
  const stored = (await cache().doc(importHash).get()).data()
  if (!stored) return undefined
  // Storage boundary: an optional field left `null` by an older write comes back
  // as an absent key, the way the domain spells absence.
  return { ...stored, result: withoutStoredNulls(stored.result) }
}

export const save = async (entry: CachedImport): Promise<CachedImport> => {
  await cache().doc(entry.importHash).set(entry)
  return entry
}
