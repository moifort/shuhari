import type { WriteBatch } from 'firebase-admin/firestore'
import { categoryRank } from '~/domain/recipe/business-rules'
import type {
  DishCategory,
  Ingredient,
  Recipe,
  RecipeId,
  RecipeSort,
  RecipeType,
  RecipeVersion,
  SortOrder,
  TmxSettings,
  VersionNumber,
} from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import { isInRequestCache, memoizedPerRequest } from '~/system/request-cache'
import {
  deleteInBatches,
  genericDataConverter,
  withoutAbsentFields,
  withoutStoredNulls,
} from '~/utils/firestore'

// How a version is spelled in Firestore, as opposed to in the domain: an absent
// field is a missing key, a plain step is a `null` placeholder in the parallel
// tmxSteps array, and the always-present arrays may be missing altogether on
// documents written before they existed.
type StoredVersion = Omit<RecipeVersion, 'ingredients' | 'tmxSteps'> & {
  ingredients?: Ingredient[]
  tmxSteps?: (TmxSettings | null)[]
}

const recipes = () => db().collection('recipes').withConverter(genericDataConverter<Recipe>())
const versions = () =>
  db().collection('recipe-versions').withConverter(genericDataConverter<StoredVersion>())

const versionDocId = (recipeId: RecipeId, number: VersionNumber) => `${recipeId}_${number}`

// Storage boundary, read side. Firestore (and any document written before the
// attempt outcome moved onto the version) spells an absent field `null`, while
// the domain spells it "absent" — so the `null`s are erased on the way in, and
// the always-present arrays are defaulted so the invariant holds on read.
const normalizeVersion = (stored: StoredVersion): RecipeVersion => ({
  ...withoutStoredNulls(stored),
  ingredients: stored.ingredients ?? [],
  tmxSteps: (stored.tmxSteps ?? []).map((settings) => settings ?? undefined),
})

// Storage boundary, write side. Every version write is a full `set` (never a
// merge), so an omitted key erases the stored field — which is precisely what an
// absent domain field means. Firestore rejects `undefined`, hence the pruning,
// and the per-step "plain step" hole is encoded as the `null` placeholder an
// array needs.
const storedVersion = (version: RecipeVersion): StoredVersion => ({
  ...withoutAbsentFields(version),
  tmxSteps: version.tmxSteps.map((settings) => settings ?? null),
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
  return data && data.userId === userId ? data : undefined
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
  return data ? normalizeVersion(data) : undefined
}

export const findVersionsOf = async (recipeId: RecipeId) => {
  const snap = await versions().where('recipeId', '==', recipeId).orderBy('number', 'asc').get()
  return snap.docs.map((doc) => normalizeVersion(doc.data()))
}

// One memoized full scan per request backs every full-lineage read (the home
// journal, the per-recipe best-rating loader) — the request pays a single query,
// mirroring `findAllByUser` for recipes.
export const findAllVersionsByUser = (userId: UserId) =>
  memoizedPerRequest(allVersionsCacheKey(userId), async () => {
    const snap = await versions().where('userId', '==', userId).get()
    return snap.docs.map((doc) => normalizeVersion(doc.data()))
  })

// Single write point for a version: its immutable content on creation, and the
// attempt outcome once it is executed. The whole document is rewritten, `set` not
// `update`, so the outcome fields land alongside the content — and a field the
// domain no longer carries is erased rather than left behind.
export const saveVersion = async (version: RecipeVersion, batch?: WriteBatch) => {
  const ref = versions().doc(versionDocId(version.recipeId, version.number))
  const stored = storedVersion(version)
  if (batch) batch.set(ref, stored)
  else await ref.set(stored)
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
