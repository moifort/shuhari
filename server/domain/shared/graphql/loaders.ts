import { RecipeQuery } from '~/domain/recipe/query'
import type { RecipeId, RecipeVersion, VersionNumber } from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'

// Per-request loaders for the satellite fields of RecipeType. One loader set
// lives on each GraphQL context (built per request in routes/graphql.ts), so
// nothing leaks across requests. Each loader memoizes per key and batches every
// key requested in the same resolution tick into a single keyed read — a page of
// recipes selecting `currentVersion` costs one getAll, never one read per recipe.

export type Loader<T, A> = { load: (arg: A) => Promise<T | undefined> }

const batchedBy = <T, A>(
  keyOf: (arg: A) => string,
  batch: (args: A[]) => Promise<Map<string, T>>,
): Loader<T, A> => {
  const cache = new Map<string, Promise<T | undefined>>()
  let pending: { arg: A; resolve: (v: T | undefined) => void; reject: (e: unknown) => void }[] = []
  const flush = async () => {
    const calls = pending
    pending = []
    try {
      const results = await batch(calls.map(({ arg }) => arg))
      for (const { arg, resolve } of calls) resolve(results.get(keyOf(arg)))
    } catch (error) {
      for (const { reject } of calls) reject(error)
    }
  }
  return {
    load: (arg) => {
      const key = keyOf(arg)
      const cached = cache.get(key)
      if (cached) return cached
      const loading = new Promise<T | undefined>((resolve, reject) => {
        if (pending.length === 0) Promise.resolve().then(() => process.nextTick(flush))
        pending.push({ arg, resolve, reject })
      })
      cache.set(key, loading)
      return loading
    },
  }
}

export type VersionRef = { recipeId: RecipeId; number: VersionNumber }

const versionKey = (ref: VersionRef) => `${ref.recipeId}_${ref.number}`

export type RecipeSatelliteLoaders = {
  version: Loader<RecipeVersion, VersionRef>
  versionsByRecipe: Loader<RecipeVersion[], RecipeId>
}

export const recipeSatelliteLoaders = (userId: UserId): RecipeSatelliteLoaders => ({
  version: batchedBy(versionKey, async (refs) => {
    const versions = await RecipeQuery.versionsByRefs(refs)
    return new Map(versions.map((v) => [versionKey({ recipeId: v.recipeId, number: v.number }), v]))
  }),
  // The full lineage of each recipe, batched from a single recipe-versions scan —
  // backs the recipe's best-note aggregate over its executed versions.
  versionsByRecipe: batchedBy(
    (recipeId) => recipeId,
    async (recipeIds) => {
      const wanted = new Set(recipeIds)
      const versions = (await RecipeQuery.allVersions(userId)).filter((v) => wanted.has(v.recipeId))
      const grouped = new Map<string, RecipeVersion[]>(recipeIds.map((id) => [id, []]))
      for (const version of versions) grouped.get(version.recipeId)?.push(version)
      return grouped
    },
  ),
})
