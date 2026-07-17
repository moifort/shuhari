import type { Home } from '~/domain/home/types'
import { RecipeType, VersionType } from '~/domain/recipe/infrastructure/graphql/types'
import { builder } from '~/domain/shared/graphql/builder'

export const HomeType = builder.objectRef<Home>('Home').implement({
  description: 'The read model behind the home screen',
  fields: (t) => ({
    toTest: t.field({
      type: [RecipeType],
      description: 'Recipes with a pending version awaiting an essai',
      resolve: (home) => home.toTest,
    }),
    library: t.field({
      type: [RecipeType],
      description: 'Every recipe (the app groups them by type)',
      resolve: (home) => home.library,
    }),
    recentEssais: t.field({
      type: [VersionType],
      description: 'Latest executed versions across all recipes, newest first',
      resolve: (home) => home.recentEssais,
    }),
  }),
})
