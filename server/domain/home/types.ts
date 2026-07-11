import type { Recipe } from '~/domain/recipe/types'
import type { Trial } from '~/domain/trial/types'

// The read model behind the home screen. `toTest` are recipes with a pending
// version awaiting a trial; `library` is every recipe (the app groups by type);
// `recentTrials` is the latest activity across all recipes.
export type Home = {
  toTest: Recipe[]
  library: Recipe[]
  recentTrials: Trial[]
}
