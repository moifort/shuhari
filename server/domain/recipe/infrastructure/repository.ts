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

// Legacy versions written before ingredients/tmxSteps became always-present
// arrays may lack the fields; default them to [] so the invariant holds on read.
const normalizeVersion = (version: RecipeVersion) => ({
  ...version,
  ingredients: version.ingredients ?? [],
  tmxSteps: version.tmxSteps ?? [],
})

const allCacheKey = (userId: UserId) => `recipes:all:${userId}`

export const findAllByUser = (userId: UserId) =>
  memoizedPerRequest(allCacheKey(userId), async () => {
    const snap = await recipes().where('userId', '==', userId).orderBy('createdAt', 'desc').get()
    return snap.docs.map((doc) => doc.data())
  })

export const findBy = async (userId: UserId, id: RecipeId) => {
  const doc = await recipes().doc(id).get()
  const data = doc.data()
  return data && data.userId === userId ? data : null
}

// Batch-load recipes by id with a single getAll — reuse the memoized full scan
// when it already ran this request (zero extra reads).
export const findManyByIds = async (userId: UserId, ids: RecipeId[]) => {
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

export const findVariationsOf = async (userId: UserId, id: RecipeId) => {
  const snap = await recipes().where('userId', '==', userId).where('derivedFrom', '==', id).get()
  return snap.docs.map((doc) => doc.data())
}

export const save = async (recipe: Recipe, batch?: WriteBatch) => {
  const ref = recipes().doc(recipe.id)
  if (batch) batch.set(ref, recipe)
  else await ref.set(recipe)
  return recipe
}

export const findVersion = async (recipeId: RecipeId, number: VersionNumber) => {
  const doc = await versions().doc(versionDocId(recipeId, number)).get()
  const data = doc.data()
  return data ? normalizeVersion(data) : null
}

export const findVersionsOf = async (recipeId: RecipeId) => {
  const snap = await versions().where('recipeId', '==', recipeId).orderBy('number', 'asc').get()
  return snap.docs.map((doc) => normalizeVersion(doc.data()))
}

export const findAllVersionsByUser = async (userId: UserId) => {
  const snap = await versions().where('userId', '==', userId).get()
  return snap.docs.map((doc) => normalizeVersion(doc.data()))
}

// Batch-load specific versions by their deterministic ids (loaders: current/toTest
// version for a page of recipes) — one getAll, one read per id.
export const findVersionsByRefs = async (refs: { recipeId: RecipeId; number: VersionNumber }[]) => {
  if (refs.length === 0) return []
  const docs = refs.map(({ recipeId, number }) => versions().doc(versionDocId(recipeId, number)))
  const snaps = await db().getAll(...docs)
  return snaps
    .map((snap) => snap.data())
    .filter((v): v is RecipeVersion => v !== undefined)
    .map(normalizeVersion)
}

export const saveVersion = async (version: RecipeVersion, batch?: WriteBatch) => {
  const ref = versions().doc(versionDocId(version.recipeId, version.number))
  if (batch) batch.set(ref, version)
  else await ref.set(version)
  return version
}

export const remove = async (id: RecipeId) => {
  const versionSnap = await versions().where('recipeId', '==', id).get()
  await deleteInBatches([recipes().doc(id), ...versionSnap.docs.map((doc) => doc.ref)])
}

export const removeAllByUser = async (userId: UserId) => {
  const recipeSnap = await recipes().where('userId', '==', userId).get()
  const versionSnap = await versions().where('userId', '==', userId).get()
  await deleteInBatches([
    ...recipeSnap.docs.map((doc) => doc.ref),
    ...versionSnap.docs.map((doc) => doc.ref),
  ])
}
