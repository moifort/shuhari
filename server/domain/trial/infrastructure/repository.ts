import type { RecipeId } from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'
import type { Trial, TrialId } from '~/domain/trial/types'
import { db } from '~/system/firebase'
import { memoizedPerRequest } from '~/system/request-cache'
import { deleteInBatches, genericDataConverter } from '~/utils/firestore'

const trials = () => db().collection('trials').withConverter(genericDataConverter<Trial>())

const allCacheKey = (userId: UserId) => `trials:all:${userId}`

// One memoized full scan per request backs every trial read (journal, recent
// activity, per-version averages, loaders) — the request pays a single query.
export const findAllByUser = (userId: UserId): Promise<Trial[]> =>
  memoizedPerRequest(allCacheKey(userId), async () => {
    const snap = await trials().where('userId', '==', userId).orderBy('executedAt', 'desc').get()
    return snap.docs.map((doc) => doc.data())
  })

export const findById = async (userId: UserId, id: TrialId): Promise<Trial | null> => {
  const doc = await trials().doc(id).get()
  const data = doc.data()
  return data && data.userId === userId ? data : null
}

export const save = async (trial: Trial): Promise<Trial> => {
  await trials().doc(trial.id).set(trial)
  return trial
}

export const removeByRecipe = async (userId: UserId, recipeId: RecipeId): Promise<void> => {
  const snap = await trials().where('userId', '==', userId).where('recipeId', '==', recipeId).get()
  await deleteInBatches(snap.docs.map((doc) => doc.ref))
}

export const removeAllByUser = async (userId: UserId): Promise<void> => {
  const snap = await trials().where('userId', '==', userId).get()
  await deleteInBatches(snap.docs.map((doc) => doc.ref))
}
