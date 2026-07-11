import type { WriteBatch } from 'firebase-admin/firestore'
import type { Recipe, RecipeId, RecipeVersion, VersionNumber } from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import { isInRequestCache, memoizedPerRequest } from '~/system/request-cache'
import { deleteInBatches, genericDataConverter } from '~/utils/firestore'

const recipes = () => db().collection('recipes').withConverter(genericDataConverter<Recipe>())
const versions = () =>
  db().collection('recipe-versions').withConverter(genericDataConverter<RecipeVersion>())

const versionDocId = (recipeId: RecipeId, number: VersionNumber) => `${recipeId}_${number}`

const allCacheKey = (userId: UserId) => `recipes:all:${userId}`

export const findAllByUser = (userId: UserId): Promise<Recipe[]> =>
  memoizedPerRequest(allCacheKey(userId), async () => {
    const snap = await recipes().where('userId', '==', userId).orderBy('createdAt', 'desc').get()
    return snap.docs.map((doc) => doc.data())
  })

export const findBy = async (userId: UserId, id: RecipeId): Promise<Recipe | null> => {
  const doc = await recipes().doc(id).get()
  const data = doc.data()
  return data && data.userId === userId ? data : null
}

// Batch-load recipes by id with a single getAll — reuse the memoized full scan
// when it already ran this request (zero extra reads).
export const findManyByIds = async (userId: UserId, ids: RecipeId[]): Promise<Recipe[]> => {
  if (ids.length === 0) return []
  if (isInRequestCache(allCacheKey(userId))) {
    const wanted = new Set(ids)
    return (await findAllByUser(userId)).filter((recipe) => wanted.has(recipe.id))
  }
  const snaps = await db().getAll(...ids.map((id) => recipes().doc(id)))
  return snaps
    .map((snap) => snap.data())
    .filter((recipe): recipe is Recipe => recipe !== undefined && recipe.userId === userId)
}

export const findVariationsOf = async (userId: UserId, id: RecipeId): Promise<Recipe[]> => {
  const snap = await recipes().where('userId', '==', userId).where('derivedFrom', '==', id).get()
  return snap.docs.map((doc) => doc.data())
}

export const save = async (recipe: Recipe, batch?: WriteBatch): Promise<Recipe> => {
  const ref = recipes().doc(recipe.id)
  if (batch) batch.set(ref, recipe)
  else await ref.set(recipe)
  return recipe
}

export const findVersion = async (
  recipeId: RecipeId,
  number: VersionNumber,
): Promise<RecipeVersion | null> => {
  const doc = await versions().doc(versionDocId(recipeId, number)).get()
  return doc.data() ?? null
}

export const findVersionsOf = async (recipeId: RecipeId): Promise<RecipeVersion[]> => {
  const snap = await versions().where('recipeId', '==', recipeId).orderBy('number', 'asc').get()
  return snap.docs.map((doc) => doc.data())
}

export const findAllVersionsByUser = async (userId: UserId): Promise<RecipeVersion[]> => {
  const snap = await versions().where('userId', '==', userId).get()
  return snap.docs.map((doc) => doc.data())
}

// Batch-load specific versions by their deterministic ids (loaders: current/toTest
// version for a page of recipes) — one getAll, one read per id.
export const findVersionsByRefs = async (
  refs: { recipeId: RecipeId; number: VersionNumber }[],
): Promise<RecipeVersion[]> => {
  if (refs.length === 0) return []
  const docs = refs.map(({ recipeId, number }) => versions().doc(versionDocId(recipeId, number)))
  const snaps = await db().getAll(...docs)
  return snaps.map((snap) => snap.data()).filter((v): v is RecipeVersion => v !== undefined)
}

export const saveVersion = async (
  version: RecipeVersion,
  batch?: WriteBatch,
): Promise<RecipeVersion> => {
  const ref = versions().doc(versionDocId(version.recipeId, version.number))
  if (batch) batch.set(ref, version)
  else await ref.set(version)
  return version
}

export const remove = async (id: RecipeId): Promise<void> => {
  const versionSnap = await versions().where('recipeId', '==', id).get()
  await deleteInBatches([recipes().doc(id), ...versionSnap.docs.map((doc) => doc.ref)])
}

export const removeAllByUser = async (userId: UserId): Promise<void> => {
  const recipeSnap = await recipes().where('userId', '==', userId).get()
  const versionSnap = await versions().where('userId', '==', userId).get()
  await deleteInBatches([
    ...recipeSnap.docs.map((doc) => doc.ref),
    ...versionSnap.docs.map((doc) => doc.ref),
  ])
}
