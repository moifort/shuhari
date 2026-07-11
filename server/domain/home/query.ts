import type { Home } from '~/domain/home/types'
import { RecipeQuery } from '~/domain/recipe/query'
import type { UserId } from '~/domain/shared/types'
import { TrialQuery } from '~/domain/trial/query'

const RECENT_TRIAL_LIMIT = 8

// Composes the home read model from the recipe and trial query surfaces (no
// repository of its own). Reads: one recipes scan + one trials scan, both
// memoized per request — three reads total once the loaders resolve the pending
// versions of the "to test" recipes.
export namespace HomeQuery {
  export const load = async (userId: UserId): Promise<Home> => {
    const [recipes, recentTrials] = await Promise.all([
      RecipeQuery.all(userId),
      TrialQuery.recent(userId, RECENT_TRIAL_LIMIT),
    ])
    return {
      toTest: recipes.filter((recipe) => recipe.toTest !== null),
      library: recipes,
      recentTrials,
    }
  }
}
