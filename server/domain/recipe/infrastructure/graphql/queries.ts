import { match } from 'ts-pattern'
import { RecipeQuery } from '~/domain/recipe/query'
import { builder } from '~/domain/shared/graphql/builder'
import { RecipeTypeEnum } from './enums'
import { RecipeType } from './types'

builder.queryField('recipes', (t) =>
  t.field({
    type: [RecipeType],
    description: 'The current user’s recipes, optionally filtered by type',
    args: { type: t.arg({ type: RecipeTypeEnum }) },
    resolve: async (_root, { type }, { userId }) => {
      const recipes = await RecipeQuery.all(userId)
      return type ? recipes.filter((recipe) => recipe.type === type) : recipes
    },
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
        .otherwise((found) => found)
    },
  }),
)
