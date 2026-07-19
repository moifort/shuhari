import { match, P } from 'ts-pattern'
import { RecipeCommand } from '~/domain/recipe/command'
import { RecipeUseCase } from '~/domain/recipe/use-case'
import { builder } from '~/domain/shared/graphql/builder'
import { domainError } from '~/domain/shared/graphql/errors'
import {
  CreateRecipeInput,
  RecordAttemptInput,
  UpdateRecipeInput,
  versionContentInput,
} from './inputs'
import { RecipeType, VersionType } from './types'

builder.mutationField('createRecipe', (t) =>
  t.field({
    type: RecipeType,
    description: [
      'Save a new recipe. Turns a confirmed import preview into a real recipe with its first ' +
        'version (`v1`). Returns the freshly created recipe.',
      '',
      '```graphql',
      'createRecipe(input: {',
      '  type: DISH',
      '  category: MAIN',
      '  title: "Grandma\'s lasagna"',
      '  content: { dish: {',
      '    ingredients: [{ name: "Flour", quantity: "250 g" }]',
      '    steps: ["Layer the pasta", "Bake at 200°C"]',
      '  } }',
      '}) {',
      '  id',
      '  versionToOpen { number }',
      '}',
      '```',
    ].join('\n'),
    args: {
      input: t.arg({
        type: CreateRecipeInput,
        required: true,
        description: 'The recipe to create — name, category, and its content',
      }),
    },
    resolve: async (_root, { input }, { userId }) => {
      const result = await RecipeCommand.create(
        userId,
        {
          type: input.type,
          category: input.category,
          title: input.title,
          content: versionContentInput(input.content),
        },
        input.sourceLabel ?? undefined,
      )
      return match(result)
        .with('content-type-mismatch', domainError)
        .with(P.not(P.string), (recipe) => recipe)
        .exhaustive()
    },
  }),
)

builder.mutationField('updateRecipe', (t) =>
  t.field({
    type: RecipeType,
    description: [
      'Retouch a recipe: rename it, mark it as a favourite, or both. Returns the updated recipe.',
      '',
      '```graphql',
      'updateRecipe(id: "9f1c-a3b2", input: { title: "Nonna\'s lasagna", favorite: true }) {',
      '  id',
      '  title',
      '  favorite',
      '}',
      '```',
    ].join('\n'),
    args: {
      id: t.arg({ type: 'RecipeId', required: true, description: 'Which recipe to update' }),
      input: t.arg({
        type: UpdateRecipeInput,
        required: true,
        description: 'What to change (leave a field out to change nothing)',
      }),
    },
    resolve: async (_root, { id, input }, { userId }) => {
      const result = await RecipeCommand.update(userId, id, {
        ...(input.title ? { title: input.title } : {}),
        ...(input.favorite !== null && input.favorite !== undefined
          ? { favorite: input.favorite }
          : {}),
      })
      return match(result)
        .with('not-found', domainError)
        .with(P.not(P.string), (recipe) => recipe)
        .exhaustive()
    },
  }),
)

builder.mutationField('deleteRecipe', (t) =>
  t.field({
    type: 'Boolean',
    description: [
      'Delete a recipe for good, along with every version and attempt on it. Returns `true` on ' +
        'success.',
      '',
      '```graphql',
      'deleteRecipe(id: "9f1c-a3b2")',
      '```',
    ].join('\n'),
    args: {
      id: t.arg({ type: 'RecipeId', required: true, description: 'Which recipe to delete' }),
    },
    resolve: async (_root, { id }, { userId }) => {
      const result = await RecipeUseCase.removeCompletely(userId, id)
      return match(result)
        .with('not-found', domainError)
        .with(P.not(P.string), () => true)
        .exhaustive()
    },
  }),
)

builder.mutationField('recordAttempt', (t) =>
  t.field({
    type: VersionType,
    description: [
      'Save what happened when you cooked a version: its rating, optionally a photo. Overwritable ' +
        '— recording again on the same version simply updates it. Fast and does not call the AI. ' +
        'Use this when the cook asks for nothing more. To iterate on what you noticed, ask for a ' +
        'proposal instead (see requestProposal): your remarks then land on the version they ' +
        'produce, and this one is left untouched. Returns the version, now updated with its outcome.',
      '',
      '```graphql',
      'recordAttempt(input: {',
      '  recipeId: "9f1c-a3b2"',
      '  versionNumber: 2',
      '  rating: 4',
      '}) {',
      '  number',
      '  rating',
      '}',
      '```',
    ].join('\n'),
    args: {
      input: t.arg({
        type: RecordAttemptInput,
        required: true,
        description: 'The attempt to record — which version, the rating, optionally a photo',
      }),
    },
    resolve: async (_root, { input }, { userId }) => {
      const result = await RecipeCommand.recordAttempt(userId, {
        recipeId: input.recipeId,
        versionNumber: input.versionNumber,
        rating: input.rating,
        ...(input.remarks ? { remarks: input.remarks } : {}),
      })
      return match(result)
        .with('not-found', domainError)
        .with(P.not(P.string), (recorded) => recorded)
        .exhaustive()
    },
  }),
)
