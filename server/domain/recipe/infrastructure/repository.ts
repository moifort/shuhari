import type { WriteBatch } from 'firebase-admin/firestore'
import { categoryRank } from '~/domain/recipe/business-rules'
import type {
  DishCategory,
  Recipe,
  RecipeId,
  RecipeSort,
  RecipeType,
  RecipeVersion,
  SortOrder,
  VersionNumber,
} from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import { isInRequestCache, memoizedPerRequest } from '~/system/request-cache'
import { deleteInBatches, genericDataConverter } from '~/utils/firestore'

const recipes = () => db().collection('recipes').withConverter(genericDataConverter<Recipe>())
const versions = () =>
  db().collection('recipe-versions').withConverter(genericDataConverter<RecipeVersion>())

const versionDocId = (recipeId: RecipeId, number: VersionNumber) => `${recipeId}_${number}`

// Legacy versions written before ingredients/tmxSteps became always-present
// arrays, or before the essai outcome was folded onto the version, may lack the
// fields; default them so the invariant holds on read (outcome null = not yet
// executed, still an "essai à faire").
const normalizeVersion = (version: RecipeVersion) => ({
  ...version,
  basedOn: version.basedOn ?? null,
  ingredients: version.ingredients ?? [],
  tmxSteps: version.tmxSteps ?? [],
  executedAt: version.executedAt ?? null,
  note: version.note ?? null,
  remarks: version.remarks ?? null,
  photoPath: version.photoPath ?? null,
})

const allCacheKey = (userId: UserId) => `recipes:all:${userId}`
const allVersionsCacheKey = (userId: UserId) => `recipe-versions:all:${userId}`

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

export const save = async (recipe: Recipe, batch?: WriteBatch) => {
  const ref = recipes().doc(recipe.id)
  // `categoryRank` is a storage-only, derived sort key (never on the domain type
  // nor exposed via GraphQL): the single write point stamps it so the library's
  // Firestore category ordering always has a fresh, cursor-safe field to sort on.
  const stored = { ...recipe, categoryRank: categoryRank(recipe.category) }
  if (batch) batch.set(ref, stored)
  else await ref.set(stored)
  return recipe
}

export type RecipePage = { recipes: Recipe[]; hasMore: boolean }
export type RecipePageArgs = {
  type?: RecipeType
  category?: DishCategory
  sort: RecipeSort
  order: SortOrder
  limit: number
  after?: RecipeId
}

// One page of the user's recipes, ordered per the requested sort. Reads limit+1
// docs to know whether a next page exists, then trims. The cursor (`after`) is
// resolved to a document snapshot so Firestore can page on the composite order;
// a stale cursor (deleted recipe) simply restarts from the top.
export const findPage = async (userId: UserId, args: RecipePageArgs): Promise<RecipePage> => {
  let query = recipes().where('userId', '==', userId)
  if (args.type) query = query.where('type', '==', args.type)
  if (args.category) query = query.where('category', '==', args.category)
  query =
    args.sort === 'category'
      ? query.orderBy('categoryRank', 'asc').orderBy('updatedAt', 'desc')
      : query.orderBy('updatedAt', args.order)
  if (args.after) {
    const cursor = await recipes().doc(args.after).get()
    if (cursor.exists) query = query.startAfter(cursor)
  }
  const snap = await query.limit(args.limit + 1).get()
  const docs = snap.docs.map((doc) => doc.data())
  const hasMore = docs.length > args.limit
  return { recipes: hasMore ? docs.slice(0, args.limit) : docs, hasMore }
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

// One memoized full scan per request backs every full-lineage read (the home
// journal, the per-recipe best-note loader) — the request pays a single query,
// mirroring `findAllByUser` for recipes.
export const findAllVersionsByUser = (userId: UserId) =>
  memoizedPerRequest(allVersionsCacheKey(userId), async () => {
    const snap = await versions().where('userId', '==', userId).get()
    return snap.docs.map((doc) => normalizeVersion(doc.data()))
  })

// Single write point for a version: its immutable content on creation, and the
// essai outcome once it is executed (the whole document is rewritten, `set` not
// `update`, so the outcome fields land alongside the content).
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
