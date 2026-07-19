import { match, P } from 'ts-pattern'
import { toTmxSettings } from '~/domain/recipe/business-rules'
import { RecipeCommand } from '~/domain/recipe/command'
import { RecipeUseCase } from '~/domain/recipe/use-case'
import { builder } from '~/domain/shared/graphql/builder'
import { domainError } from '~/domain/shared/graphql/errors'
import { CreateRecipeInput, RecordEssaiInput, UpdateRecipeInput } from './inputs'
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
      '  type: PLAT',
      '  category: PLAT',
      '  title: "Grandma\'s lasagna"',
      '  ingredients: [{ name: "Flour", quantity: "250 g" }]',
      '  steps: ["Layer the pasta", "Bake at 200°C"]',
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
        description: 'The recipe to create — name, category, ingredients, steps…',
      }),
    },
    resolve: async (_root, { input }, { userId }) =>
      RecipeCommand.create(
        userId,
        {
          type: input.type,
          category: input.category,
          title: input.title,
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
    description: [
      'Rename a recipe — change its title. Returns the updated recipe.',
      '',
      '```graphql',
      'updateRecipe(id: "9f1c-a3b2", input: { title: "Nonna\'s lasagna" }) {',
      '  id',
      '  title',
      '}',
      '```',
    ].join('\n'),
    args: {
      id: t.arg({ type: 'RecipeId', required: true, description: 'Which recipe to rename' }),
      input: t.arg({
        type: UpdateRecipeInput,
        required: true,
        description: 'The new title (leave it out to change nothing)',
      }),
    },
    resolve: async (_root, { id, input }, { userId }) => {
      const result = await RecipeCommand.rename(userId, id, input.title ?? undefined)
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

builder.mutationField('recordEssai', (t) =>
  t.field({
    type: VersionType,
    description: [
      'Save what happened when you cooked a version: its rating and your notes. Overwritable — ' +
        'recording again on the same version simply updates it. Fast and does not call the AI. If ' +
        'the rating is low and you want a suggested improvement, ask for a proposition separately ' +
        '(see requestProposition). Returns the version, now updated with its outcome.',
      '',
      '```graphql',
      'recordEssai(input: {',
      '  recipeId: "9f1c-a3b2"',
      '  versionNumber: 2',
      '  note: 4',
      '  remarks: "Still a touch too sweet, but the texture is spot on"',
      '}) {',
      '  number',
      '  note',
      '}',
      '```',
    ].join('\n'),
    args: {
      input: t.arg({
        type: RecordEssaiInput,
        required: true,
        description: 'The attempt to record — which version, the rating, the notes',
      }),
    },
    resolve: async (_root, { input }, { userId }) => {
      const result = await RecipeCommand.recordEssai(userId, {
        recipeId: input.recipeId,
        versionNumber: input.versionNumber,
        note: input.note,
        remarks: input.remarks,
        photoPath: null,
      })
      return match(result)
        .with('not-found', domainError)
        .with(P.not(P.string), (recorded) => recorded)
        .exhaustive()
    },
  }),
)
