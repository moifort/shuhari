import { RecipeQuery } from '~/domain/recipe/query'
import type { UserId } from '~/domain/shared/types'

const RECENT_ESSAI_LIMIT = 8

// Composes the home read model from the recipe query surface alone (no repository
// of its own). Reads: one recipes scan + one recipe-versions scan, both memoized
// per request — the recent essais are the executed versions from that same scan,
// newest first.
export namespace HomeQuery {
  export const load = async (userId: UserId) => {
    const [recipes, versions] = await Promise.all([
      RecipeQuery.all(userId),
      RecipeQuery.allVersions(userId),
    ])
    const recentEssais = versions
      .filter((version) => version.executedAt !== null)
      .sort((a, b) => (b.executedAt as Date).getTime() - (a.executedAt as Date).getTime())
      .slice(0, RECENT_ESSAI_LIMIT)
    return {
      toTest: recipes.filter((recipe) => recipe.toTest !== null),
      library: recipes,
      recentEssais,
    }
  }
}
