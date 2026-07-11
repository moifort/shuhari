import type { CachedImport, ImportHash } from '~/system/ai/types'
import { db } from '~/system/firebase'
import { genericDataConverter } from '~/utils/firestore'

const cache = () =>
  db().collection('import-cache').withConverter(genericDataConverter<CachedImport>())

export const findBy = async (importHash: ImportHash): Promise<CachedImport | null> => {
  const doc = await cache().doc(importHash).get()
  return doc.data() ?? null
}

export const save = async (entry: CachedImport): Promise<CachedImport> => {
  await cache().doc(entry.importHash).set(entry)
  return entry
}
