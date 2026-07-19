import type { CachedImport, ImportAnalysis, ImportHash, ImportTmxSettings } from '~/system/ai/types'
import { db } from '~/system/firebase'
import { genericDataConverter, withoutStoredNulls } from '~/utils/firestore'

// How a cached analysis is spelled in Firestore: the parallel tmxSteps array is
// positional, so a plain step — absent in the domain — keeps its slot as the
// `null` placeholder Firestore accepts (it rejects `undefined` outright).
type StoredImport = Omit<CachedImport, 'result'> & {
  result: Omit<ImportAnalysis, 'tmxSteps'> & { tmxSteps?: (ImportTmxSettings | null)[] }
}

const cache = () =>
  db().collection('import-cache').withConverter(genericDataConverter<StoredImport>())

export const findBy = async (importHash: ImportHash): Promise<CachedImport | undefined> => {
  const stored = (await cache().doc(importHash).get()).data()
  if (!stored) return undefined
  const { tmxSteps, ...result } = withoutStoredNulls(stored.result)
  return {
    ...stored,
    result: { ...result, ...(tmxSteps ? { tmxSteps: tmxSteps.map((s) => s ?? undefined) } : {}) },
  }
}

export const save = async (entry: CachedImport): Promise<CachedImport> => {
  const { tmxSteps, ...result } = entry.result
  await cache()
    .doc(entry.importHash)
    .set({
      ...entry,
      result: { ...result, ...(tmxSteps ? { tmxSteps: tmxSteps.map((s) => s ?? null) } : {}) },
    })
  return entry
}
