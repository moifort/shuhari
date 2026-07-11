import type { Home } from '~/domain/home/types'
import { RecipeType } from '~/domain/recipe/infrastructure/graphql/types'
import { builder } from '~/domain/shared/graphql/builder'
import { TrialType } from '~/domain/trial/infrastructure/graphql/types'

export const HomeType = builder.objectRef<Home>('Home').implement({
  description: 'The read model behind the home screen',
  fields: (t) => ({
    toTest: t.field({
      type: [RecipeType],
      description: 'Recipes with a pending version awaiting a trial',
      resolve: (home) => home.toTest,
    }),
    library: t.field({
      type: [RecipeType],
      description: 'Every recipe (the app groups them by type)',
      resolve: (home) => home.library,
    }),
    recentTrials: t.field({
      type: [TrialType],
      description: 'Latest trials across all recipes',
      resolve: (home) => home.recentTrials,
    }),
  }),
})
