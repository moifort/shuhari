import { match, P } from 'ts-pattern'
import { RecipeQuery } from '~/domain/recipe/query'
import { builder } from '~/domain/shared/graphql/builder'
import { RecipeSortEnum, RecipeTypeEnum, SortOrderEnum } from './enums'
import { RecipesType, RecipeType } from './types'

builder.queryField('recipes', (t) =>
  t.field({
    type: RecipesType,
    description:
      'A page of the current user’s recipe library, filtered by type and sorted per view',
    args: {
      type: t.arg({ type: RecipeTypeEnum, description: 'Facet: keep only this recipe type' }),
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
    description: 'A single recipe by id',
    args: { id: t.arg({ type: 'RecipeId', required: true }) },
    resolve: async (_root, { id }, { userId }) => {
      const recipe = await RecipeQuery.byId(userId, id)
      return match(recipe)
        .with('not-found', () => null)
        .with(P.not(P.string), (found) => found)
        .exhaustive()
    },
  }),
)
