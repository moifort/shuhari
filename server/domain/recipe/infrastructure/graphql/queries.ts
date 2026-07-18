import { match, P } from 'ts-pattern'
import { RecipeQuery } from '~/domain/recipe/query'
import { builder } from '~/domain/shared/graphql/builder'
import { DishCategoryEnum, RecipeSortEnum, RecipeTypeEnum, SortOrderEnum } from './enums'
import { RecipesType, RecipeType } from './types'

builder.queryField('recipes', (t) =>
  t.field({
    type: RecipesType,
    description:
      'One page of your recipe library, loaded a few at a time for infinite scroll. You can ' +
      'narrow it (e.g. only TMX recipes, or only desserts) and choose the order. For example: ' +
      'the 20 most recently updated dishes, then pass the last id as "after" to load the next 20.',
    args: {
      type: t.arg({ type: RecipeTypeEnum, description: 'Facet: keep only this recipe type' }),
      category: t.arg({
        type: DishCategoryEnum,
        description:
          'Facet: keep only this dish category. When set, the page is coerced to ' +
          'updatedAt desc — the sort/order args are ignored (ranking within one ' +
          'category is meaningless, and it keeps the composite-index surface bounded)',
      }),
      sort: t.arg({
        type: RecipeSortEnum,
        defaultValue: 'updatedAt',
        description: 'Field the page is ordered by',
      }),
      order: t.arg({
        type: SortOrderEnum,
        defaultValue: 'desc',
        description: 'Sort direction (ignored for the category sort, which is fixed)',
      }),
      limit: t.arg.int({ defaultValue: 20, description: 'Maximum recipes returned in the page' }),
      after: t.arg({
        type: 'RecipeId',
        description: 'Cursor: return the page following this recipe id',
      }),
    },
    resolve: async (_root, args, { userId }) =>
      RecipeQuery.library(userId, {
        type: args.type ?? undefined,
        category: args.category ?? undefined,
        sort: args.sort ?? 'updatedAt',
        order: args.order ?? 'desc',
        limit: args.limit ?? 20,
        after: args.after ?? undefined,
      }),
  }),
)

builder.queryField('recipe', (t) =>
  t.field({
    type: RecipeType,
    nullable: true,
    description:
      'Fetch one recipe by its id, with everything on it. Returns null if no such recipe exists.',
    args: {
      id: t.arg({ type: 'RecipeId', required: true, description: 'The id of the recipe to fetch' }),
    },
    resolve: async (_root, { id }, { userId }) => {
      const recipe = await RecipeQuery.byId(userId, id)
      return match(recipe)
        .with('not-found', () => null)
        .with(P.not(P.string), (found) => found)
        .exhaustive()
    },
  }),
)
