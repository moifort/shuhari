import { match, P } from 'ts-pattern'
import { toTmxSettings } from '~/domain/recipe/business-rules'
import { RecipeCommand } from '~/domain/recipe/command'
import { RecipeUseCase } from '~/domain/recipe/use-case'
import { builder } from '~/domain/shared/graphql/builder'
import { domainError, notFound } from '~/domain/shared/graphql/errors'
import { CreateRecipeInput, UpdateRecipeInput } from './inputs'
import { RecipeType } from './types'

builder.mutationField('createRecipe', (t) =>
  t.field({
    type: RecipeType,
    description: 'Create a recipe and its v1 from a confirmed import preview',
    args: { input: t.arg({ type: CreateRecipeInput, required: true }) },
    resolve: async (_root, { input }, { userId }) =>
      RecipeCommand.importRecipe(
        userId,
        {
          type: input.type,
          category: input.category,
          title: input.title,
          ...(input.subtitle ? { subtitle: input.subtitle } : {}),
          steps: input.steps,
          ingredients: input.ingredients ?? [],
          tmxSteps: input.tmxSteps ? toTmxSettings(input.tmxSteps) : [],
        },
        input.sourceLabel ?? undefined,
      ),
  }),
)

builder.mutationField('updateRecipe', (t) =>
  t.field({
    type: RecipeType,
    description: 'Rename a recipe (title and/or subtitle)',
    args: {
      id: t.arg({ type: 'RecipeId', required: true }),
      input: t.arg({ type: UpdateRecipeInput, required: true }),
    },
    resolve: async (_root, { id, input }, { userId }) => {
      const result = await RecipeCommand.rename(userId, id, {
        ...(input.title ? { title: input.title } : {}),
        ...(input.subtitle ? { subtitle: input.subtitle } : {}),
      })
      return match(result)
        .with('not-found', () => notFound('Recipe not found'))
        .with(P.not(P.string), (recipe) => recipe)
        .exhaustive()
    },
  }),
)

builder.mutationField('promoteVersion', (t) =>
  t.field({
    type: RecipeType,
    description: 'Promote a pending version to the current reference (after a high-scoring trial)',
    args: {
      recipeId: t.arg({ type: 'RecipeId', required: true }),
      versionNumber: t.arg({ type: 'VersionNumber', required: true }),
    },
    resolve: async (_root, { recipeId, versionNumber }, { userId }) => {
      const result = await RecipeCommand.promote(userId, recipeId, versionNumber)
      return match(result)
        .with('not-found', () => notFound('Recipe not found'))
        .with('nothing-to-test', () =>
          domainError('NOTHING_TO_TEST', 'No version awaiting a trial'),
        )
        .with(P.not(P.string), (recipe) => recipe)
        .exhaustive()
    },
  }),
)

builder.mutationField('deleteRecipe', (t) =>
  t.field({
    type: 'Boolean',
    description: 'Delete a recipe and all its versions, trials and proposals',
    args: { id: t.arg({ type: 'RecipeId', required: true }) },
    resolve: async (_root, { id }, { userId }) => {
      const result = await RecipeUseCase.removeCompletely(userId, id)
      return match(result)
        .with('not-found', () => notFound('Recipe not found'))
        .with(P.not(P.string), () => true)
        .exhaustive()
    },
  }),
)
