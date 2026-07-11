import { ProposalQuery } from '~/domain/proposal/query'
import type { Proposal } from '~/domain/proposal/types'
import { RecipeQuery } from '~/domain/recipe/query'
import type { Recipe, RecipeId, RecipeVersion, VersionNumber } from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'
import { TrialQuery } from '~/domain/trial/query'
import type { Trial } from '~/domain/trial/types'

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
export type ProposalRef = { recipeId: RecipeId; versionNumber: VersionNumber }

const versionKey = (ref: VersionRef) => `${ref.recipeId}_${ref.number}`
const proposalKey = (ref: ProposalRef) => `${ref.recipeId}_${ref.versionNumber}`

export type RecipeSatelliteLoaders = {
  version: Loader<RecipeVersion, VersionRef>
  trials: Loader<Trial[], RecipeId>
  proposal: Loader<Proposal, ProposalRef>
  variations: Loader<Recipe[], RecipeId>
}

export const recipeSatelliteLoaders = (userId: UserId): RecipeSatelliteLoaders => ({
  version: batchedBy(versionKey, async (refs) => {
    const versions = await RecipeQuery.versionsByRefs(refs)
    return new Map(versions.map((v) => [versionKey({ recipeId: v.recipeId, number: v.number }), v]))
  }),
  trials: batchedBy(
    (recipeId) => recipeId,
    async (recipeIds) => {
      const trials = await TrialQuery.byRecipeIds(userId, recipeIds)
      const grouped = new Map<string, Trial[]>(recipeIds.map((id) => [id, []]))
      for (const trial of trials) grouped.get(trial.recipeId)?.push(trial)
      return grouped
    },
  ),
  proposal: batchedBy(proposalKey, async (refs) => {
    const proposals = await ProposalQuery.byRefs(refs)
    return new Map(
      proposals.map((p) => [
        proposalKey({ recipeId: p.recipeId, versionNumber: p.versionNumber }),
        p,
      ]),
    )
  }),
  variations: batchedBy(
    (recipeId) => recipeId,
    async (recipeIds) => {
      const all = await RecipeQuery.all(userId)
      const grouped = new Map<string, Recipe[]>(recipeIds.map((id) => [id, []]))
      for (const recipe of all)
        if (recipe.derivedFrom) grouped.get(recipe.derivedFrom)?.push(recipe)
      return grouped
    },
  ),
})
