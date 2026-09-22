import type { Transaction } from 'firebase-admin/firestore'
import { chunk } from 'lodash-es'
import { categoryRank, methodRank } from '~/domain/recipe/business-rules'
import type {
  BrewMethod,
  DishCategory,
  Recipe,
  RecipeId,
  RecipeSort,
  RecipeType,
  RecipeVersion,
  SortOrder,
  VersionNumber,
} from '~/domain/recipe/types'
import { type CoffeeVocabulary, emptyVocabulary } from '~/domain/recipe/vocabulary'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import { isInRequestCache, memoizedPerRequest } from '~/system/request-cache'
import {
  bulkSave,
  deleteInBatches,
  genericDataConverter,
  withoutAbsentFields,
  withoutStoredNulls,
} from '~/utils/firestore'

const recipes = () => db().collection('recipes').withConverter(genericDataConverter<Recipe>())
const versions = () =>
  db().collection('recipe-versions').withConverter(genericDataConverter<RecipeVersion>())

const vocabularies = () =>
  db().collection('coffee-vocabularies').withConverter(genericDataConverter<CoffeeVocabulary>())

const versionDocId = (recipeId: RecipeId, number: VersionNumber) => `${recipeId}_${number}`

// Storage boundary, read side. Firestore (and any document written before the
// attempt outcome moved onto the version) spells an absent envelope field `null`,
// while the domain spells it "absent" — so the top-level `null`s are erased on the
// way in. The nested `content` is built total, a plain Thermomix step being the
// empty settings object `{}` Firestore stores verbatim; its one defaulted field is
// the cooking `miseEnPlace`, total in the domain like `tips` and `warnings`, so a
// document written before the field existed (or restored from such an export)
// reads as the empty list. `updatedAt` is total too: a version never rewritten
// since the field landed — or restored from an older export — was last modified
// when it was created.
const normalizeVersion = (stored: RecipeVersion): RecipeVersion => ({
  ...withoutStoredNulls(stored),
  content:
    stored.content.kind === 'coffee'
      ? stored.content
      : { ...stored.content, miseEnPlace: stored.content.miseEnPlace ?? [] },
  tips: stored.tips ?? [],
  warnings: stored.warnings ?? [],
  updatedAt: stored.updatedAt ?? stored.createdAt,
})

// Storage boundary, write side. Every version write is a full `set` (never a
// merge), so an omitted key erases the stored field — which is precisely what an
// absent domain field means. Firestore rejects `undefined`, hence the pruning
// (shallow: it only prunes absent envelope fields; the `content` object is written
// verbatim, empty `settings: {}` steps included — it is built without any
// `undefined`, so nothing nested needs pruning).
const storedVersion = (version: RecipeVersion): RecipeVersion => withoutAbsentFields(version)

const allCacheKey = (userId: UserId) => `recipes:all:${userId}`
const allVersionsCacheKey = (userId: UserId) => `recipe-versions:all:${userId}`

export const findAllByUser = (userId: UserId) =>
  memoizedPerRequest(allCacheKey(userId), async () => {
    const snap = await recipes().where('userId', '==', userId).orderBy('createdAt', 'desc').get()
    return snap.docs.map((doc) => doc.data())
  })

// Every read below takes an optional transaction: a command reads through it, so
// what it writes back is a function of the state it read and nothing else (see
// `transactionally`). Without one, a plain read.
export const findBy = async (userId: UserId, id: RecipeId, tx?: Transaction) => {
  const ref = recipes().doc(id)
  const doc = tx ? await tx.get(ref) : await ref.get()
  const data = doc.data()
  return data && data.userId === userId ? data : undefined
}

// Batch-load recipes by id with a single getAll — reuse the memoized full scan
// when it already ran this request (zero extra reads).
export const findManyByIds = async (userId: UserId, ids: RecipeId[]) => {
  if (ids.length === 0) return []
  if (isInRequestCache(allCacheKey(userId))) {
    const wanted = new Set(ids)
    return (await findAllByUser(userId)).filter(({ id }) => wanted.has(id))
  }
  const snaps = await db().getAll(...ids.map((id) => recipes().doc(id)))
  return snaps
    .map((snap) => snap.data())
    .filter((recipe): recipe is Recipe => recipe !== undefined && recipe.userId === userId)
}

// The composition link read the other way round: the recipes that are made of this
// one. `componentIds` is what makes it one query — `array-contains` cannot look
// inside `components`, whose entries are objects. Memoized per request, like every
// other read a single sheet can ask for twice.
export const findUsersOf = (userId: UserId, id: RecipeId) =>
  memoizedPerRequest(`recipes:used-by:${userId}:${id}`, async () => {
    const snap = await recipes()
      .where('userId', '==', userId)
      .where('componentIds', 'array-contains', id)
      .get()
    return snap.docs.map((doc) => doc.data())
  })

export const save = async (recipe: Recipe, tx?: Transaction) => {
  const ref = recipes().doc(recipe.id)
  // `categoryRank` and `methodRank` are storage-only, derived sort keys (never on
  // the domain type nor exposed via GraphQL): the single write point stamps them so
  // the library's and the coffee tab's Firestore ordering always have a fresh,
  // cursor-safe field to sort on. Only a coffee carries a method, hence a rank.
  const stored = {
    ...recipe,
    categoryRank: categoryRank(recipe.category),
    ...(recipe.method ? { methodRank: methodRank(recipe.method) } : {}),
  }
  if (tx) tx.set(ref, stored)
  else await ref.set(stored)
  return recipe
}

export type RecipePage = { recipes: Recipe[]; hasMore: boolean }
export type RecipePageArgs = {
  // The types the page is about: `[dish, thermomix]` for the cooking notebook,
  // `[coffee]` for the coffee tab. Absent = every type.
  types?: RecipeType[]
  category?: DishCategory
  method?: BrewMethod
  favorite?: true
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
  // A single type is an equality (one index scan); several make it an `in`, which
  // Firestore runs as one scan per value over the very same composite index.
  if (args.types?.length === 1) query = query.where('type', '==', args.types[0])
  else if (args.types?.length) query = query.where('type', 'in', args.types)
  if (args.category) query = query.where('category', '==', args.category)
  if (args.method) query = query.where('method', '==', args.method)
  // Favourites are marked by the field's presence, so equality on `true` is also
  // what excludes every recipe that never carried it.
  if (args.favorite) query = query.where('favorite', '==', true)
  // Filed by course or by brew method, a section reads the same way: the hearted
  // recipes first, then the best rating (`standing`), the freshest among equals.
  // Narrowed to one course or one method, every row holds the same rank: ordering on
  // it would only demand one more index.
  const narrowed = args.category !== undefined || args.method !== undefined
  const filedBy = (rank: 'categoryRank' | 'methodRank') =>
    (narrowed ? query : query.orderBy(rank, 'asc'))
      .orderBy('standing', 'desc')
      .orderBy('updatedAt', 'desc')
  query =
    args.sort === 'category'
      ? filedBy('categoryRank')
      : args.sort === 'method'
        ? filedBy('methodRank')
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

export const findVersion = async (recipeId: RecipeId, number: VersionNumber, tx?: Transaction) => {
  const ref = versions().doc(versionDocId(recipeId, number))
  const doc = tx ? await tx.get(ref) : await ref.get()
  const data = doc.data()
  return data ? normalizeVersion(data) : undefined
}

// One recipe's lineage, for the commands that rewrite it (deleting a version has to
// rebase its children). Reads go through the batched loader instead — see
// `findAllVersionsByUser`.
export const findVersionsOf = async (recipeId: RecipeId, tx?: Transaction) => {
  const query = versions().where('recipeId', '==', recipeId).orderBy('number', 'asc')
  const snap = tx ? await tx.get(query) : await query.get()
  return snap.docs.map((doc) => normalizeVersion(doc.data()))
}

// Firestore caps an `in` filter at 30 values, so a page wider than that fans out
// into several parallel queries.
const IN_FILTER_LIMIT = 30

// The lineages of a bounded set of recipes — what the satellite loader pays for a
// page: the versions of the recipes on screen, never the whole notebook. Scales with
// the page, not with the size of the library, which is what a full scan did.
// No `userId` filter: the ids come from recipes already resolved under the cook's
// scope, and pairing `in` with an equality would demand a composite index where the
// `recipeId` one already serves.
export const findVersionsOfMany = async (recipeIds: RecipeId[]) => {
  if (recipeIds.length === 0) return []
  const pages = await Promise.all(
    chunk(recipeIds, IN_FILTER_LIMIT).map((ids) => versions().where('recipeId', 'in', ids).get()),
  )
  return pages.flatMap(({ docs }) => docs.map((doc) => normalizeVersion(doc.data())))
}

// One memoized full scan per request, for the whole-notebook reads alone (the
// export). Never a read path behind GraphQL: those go through `findVersionsOfMany`.
export const findAllVersionsByUser = (userId: UserId) =>
  memoizedPerRequest(allVersionsCacheKey(userId), async () => {
    const snap = await versions().where('userId', '==', userId).get()
    return snap.docs.map((doc) => normalizeVersion(doc.data()))
  })

// Single write point for a version: its immutable content on creation, and the
// attempt outcome once it is executed. The whole document is rewritten, `set` not
// `update`, so the outcome fields land alongside the content — and a field the
// domain no longer carries is erased rather than left behind.
export const saveVersion = async (version: RecipeVersion, tx?: Transaction) => {
  const ref = versions().doc(versionDocId(version.recipeId, version.number))
  const stored = storedVersion(version)
  if (tx) tx.set(ref, stored)
  else await ref.set(stored)
  return version
}

export const removeVersion = async (
  recipeId: RecipeId,
  number: VersionNumber,
  tx?: Transaction,
) => {
  const ref = versions().doc(versionDocId(recipeId, number))
  if (tx) tx.delete(ref)
  else await ref.delete()
}

// The recipe and its whole lineage, in the caller's transaction — which has read
// that lineage already: a transaction reads everything before it writes anything,
// so a version added concurrently replays the deletion instead of surviving it as
// an orphan.
export const remove = (id: RecipeId, lineage: RecipeVersion[], tx: Transaction) => {
  tx.delete(recipes().doc(id))
  for (const { number } of lineage) tx.delete(versions().doc(versionDocId(id, number)))
}

// Restore: the cook's notebook becomes exactly what the export carried. The
// incoming rows are written BEFORE anything is deleted, and only what the import
// does not carry is then removed. The reverse order — wipe, then write — is a
// window in which the notebook is empty: a crash or a function timeout inside it
// left the cook with nothing at all, and the export they restored from was their
// only copy. This way the worst a half-finished restore leaves is the imported
// notebook plus a few rows it was meant to replace, and re-running it finishes
// the job. Ids are deterministic, so writing over an existing row is an overwrite,
// never a duplicate.
export const replaceAllByUser = async (
  userId: UserId,
  incomingRecipes: Recipe[],
  incomingVersions: RecipeVersion[],
) => {
  const [recipeSnap, versionSnap] = await Promise.all([
    recipes().where('userId', '==', userId).get(),
    versions().where('userId', '==', userId).get(),
  ])
  await bulkSave(incomingRecipes, (recipe) => save(recipe))
  await bulkSave(incomingVersions, (version) => saveVersion(version))

  const restoredRecipes = new Set(incomingRecipes.map(({ id }) => String(id)))
  const restoredVersions = new Set(
    incomingVersions.map(({ recipeId, number }) => versionDocId(recipeId, number)),
  )
  await deleteInBatches([
    ...recipeSnap.docs.filter(({ ref }) => !restoredRecipes.has(ref.id)).map(({ ref }) => ref),
    ...versionSnap.docs.filter(({ ref }) => !restoredVersions.has(ref.id)).map(({ ref }) => ref),
  ])
}

export const removeAllByUser = async (userId: UserId) => {
  const [recipeSnap, versionSnap] = await Promise.all([
    recipes().where('userId', '==', userId).get(),
    versions().where('userId', '==', userId).get(),
  ])
  await deleteInBatches([
    ...recipeSnap.docs.map(({ ref }) => ref),
    ...versionSnap.docs.map(({ ref }) => ref),
    // The vocabulary is learned from the recipes: it goes with them.
    vocabularies().doc(userId),
  ])
}

// The cook's coffee vocabulary, or an empty one when they have never saved a coffee.
// One keyed document, so it costs the same read whatever the size of the library.
export const findVocabulary = async (
  userId: UserId,
  tx?: Transaction,
): Promise<CoffeeVocabulary> => {
  const ref = vocabularies().doc(userId)
  const doc = tx ? await tx.get(ref) : await ref.get()
  return doc.data() ?? emptyVocabulary(userId)
}

// Written in the same transaction as the version that taught it: a version saved
// without its vocabulary, or the reverse, must not exist.
export const saveVocabulary = async (vocabulary: CoffeeVocabulary, tx?: Transaction) => {
  const ref = vocabularies().doc(vocabulary.userId)
  if (tx) tx.set(ref, vocabulary)
  else await ref.set(vocabulary)
  return vocabulary
}
