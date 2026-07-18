import type { Home } from '~/domain/home/types'
import { RecipeType, VersionType } from '~/domain/recipe/infrastructure/graphql/types'
import { builder } from '~/domain/shared/graphql/builder'

export const HomeType = builder.objectRef<Home>('Home').implement({
  description:
    'The read model behind the home screen, e.g. `"Grandma’s lasagna v3"` waiting to be cooked ' +
    'plus yesterday’s risotto essai',
  fields: (t) => ({
    toTest: t.field({
      type: [RecipeType],
      description:
        'Recipes with a pending version awaiting an essai, e.g. `"Grandma’s lasagna"` whose `v3` ' +
        'is queued up',
      resolve: (home) => home.toTest,
    }),
    library: t.field({
      type: [RecipeType],
      description:
        'Every recipe (the app groups them by type), e.g. `"Grandma’s lasagna"` and `"Tarte tatin"`',
      resolve: (home) => home.library,
    }),
    recentEssais: t.field({
      type: [VersionType],
      description:
        'Latest executed versions across all recipes, newest first, e.g. the risotto `v2` you ' +
        'rated `4` yesterday',
      resolve: (home) => home.recentEssais,
    }),
  }),
})
