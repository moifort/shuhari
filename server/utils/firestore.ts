import type {
  DocumentData,
  DocumentReference,
  FirestoreDataConverter,
  QueryDocumentSnapshot,
  WriteBatch,
} from 'firebase-admin/firestore'
import { chunk } from 'lodash-es'
import { db } from '~/system/firebase'

// Generic Firestore converter that preserves type information when reading
// documents and recursively turns Timestamp instances back into JS Date.
export const genericDataConverter = <T extends DocumentData>(): FirestoreDataConverter<T> => ({
  toFirestore: (data: T) => data,
  fromFirestore: (snapshot: QueryDocumentSnapshot) => toDate(snapshot.data()) as T,
})

const toDate = (value: unknown): unknown => {
  if (!value || typeof value !== 'object') return value
  const obj = value as Record<string, unknown>
  for (const key of Object.keys(obj)) {
    const v = obj[key] as { toDate?: () => Date } | unknown
    if (v && typeof v === 'object' && typeof (v as { toDate?: unknown }).toDate === 'function') {
      obj[key] = (v as { toDate: () => Date }).toDate()
    } else if (v && typeof v === 'object') {
      toDate(v)
    }
  }
  return obj
}

// Firestore batches accept at most 500 operations.
const BATCH_LIMIT = 400

// Persist many records with bounded write concurrency — individual sets, not a
// batch (the row count on an import/restore can exceed the 500-op batch cap).
export const bulkSave = async <T>(rows: T[], save: (row: T) => Promise<unknown>): Promise<void> => {
  for (const slice of chunk(rows, 50)) await Promise.all(slice.map((row) => save(row)))
}

export const deleteInBatches = async (refs: DocumentReference[]): Promise<void> => {
  for (const slice of chunk(refs, BATCH_LIMIT)) {
    const batch = db().batch()
    for (const ref of slice) batch.delete(ref)
    await batch.commit()
  }
}

// Runs `enlist` against a fresh WriteBatch and commits it once: either every
// enlisted write lands or none does. Reads inside `enlist` see pre-batch state —
// batched writes are invisible until commit. Firestore caps a batch at 500
// writes; callers enlist a handful of documents, far below the cap.
export const atomically = async <T>(enlist: (batch: WriteBatch) => Promise<T>): Promise<T> => {
  const batch = db().batch()
  const result = await enlist(batch)
  await batch.commit()
  return result
}
