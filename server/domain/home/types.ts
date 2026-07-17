import type { Recipe, RecipeVersion } from '~/domain/recipe/types'

// The read model behind the home screen. `toTest` are recipes with a pending
// version awaiting an essai; `library` is every recipe (the app groups by type);
// `recentEssais` is the latest executed versions across all recipes.
export type Home = {
  toTest: Recipe[]
  library: Recipe[]
  recentEssais: RecipeVersion[]
}
