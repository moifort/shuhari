import { match, P } from 'ts-pattern'
import { toTmxSettings } from '~/domain/recipe/business-rules'
import { RecipeCommand, type RecordEssaiResult } from '~/domain/recipe/command'
import { RecipeUseCase } from '~/domain/recipe/use-case'
import { builder } from '~/domain/shared/graphql/builder'
import { domainError } from '~/domain/shared/graphql/errors'
import { CreateRecipeInput, RecordEssaiInput, UpdateRecipeInput } from './inputs'
import { RecipeType, VersionType } from './types'

const RecordEssaiResultType = builder.objectRef<RecordEssaiResult>('RecordEssaiResult').implement({
  description: 'What you get back after saving the result of an attempt, e.g. `v2` rated `4`',
  fields: (t) => ({
    version: t.field({
      type: VersionType,
      description:
        'The version you just rated, now updated with its note and remarks, e.g. `v2` with note `4`',
      resolve: (r) => r.version,
    }),
    promotionSuggested: t.boolean({
      description:
        '`true` when this attempt — run on the pending version — scored `4` or more, so this ' +
        'version can now become the recipe’s new reference; the app then offers to "promote" it',
      resolve: (r) => r.promotionSuggested,
    }),
  }),
})

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
      '  toTest { number }',
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
    description: [
      'Rename a recipe — change its title and/or its subtitle. Returns the updated recipe.',
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
        description: 'The new title/subtitle (send only what changes)',
      }),
    },
    resolve: async (_root, { id, input }, { userId }) => {
      const result = await RecipeCommand.rename(userId, id, {
        ...(input.title ? { title: input.title } : {}),
        ...(input.subtitle ? { subtitle: input.subtitle } : {}),
      })
      return match(result)
        .with('not-found', domainError)
        .with(P.not(P.string), (recipe) => recipe)
        .exhaustive()
    },
  }),
)

builder.mutationField('promoteVersion', (t) =>
  t.field({
    type: RecipeType,
    description: [
      'Crown a version as the recipe’s new reference (its "currentVersion") — do this after an ' +
        'attempt scored `4` or more. Returns the updated recipe.',
      '',
      '```graphql',
      'promoteVersion(recipeId: "9f1c-a3b2", versionNumber: 2) {',
      '  currentVersion { number note }',
      '}',
      '```',
    ].join('\n'),
    args: {
      recipeId: t.arg({ type: 'RecipeId', required: true, description: 'Which recipe' }),
      versionNumber: t.arg({
        type: 'VersionNumber',
        required: true,
        description: 'Which version to make the reference, e.g. `2`',
      }),
    },
    resolve: async (_root, { recipeId, versionNumber }, { userId }) => {
      const result = await RecipeCommand.promote(userId, recipeId, versionNumber)
      return match(result)
        .with('not-found', domainError)
        .with('nothing-to-test', domainError)
        .with(P.not(P.string), (recipe) => recipe)
        .exhaustive()
    },
  }),
)

builder.mutationField('discardPendingVersion', (t) =>
  t.field({
    type: 'Boolean',
    description: [
      'Drop a planned-but-not-yet-cooked version from the to-do list and delete it. Returns ' +
        '`true` on success. Won’t delete a recipe’s only version.',
      '',
      '```graphql',
      'discardPendingVersion(recipeId: "9f1c-a3b2", versionNumber: 3)',
      '```',
    ].join('\n'),
    args: {
      recipeId: t.arg({ type: 'RecipeId', required: true, description: 'Which recipe' }),
      versionNumber: t.arg({
        type: 'VersionNumber',
        required: true,
        description: 'Which pending (untried) version to discard, e.g. `3`',
      }),
    },
    resolve: async (_root, { recipeId, versionNumber }, { userId }) => {
      const result = await RecipeCommand.discardPending(userId, recipeId, versionNumber)
      return match(result)
        .with('not-found', domainError)
        .with('nothing-to-discard', domainError)
        .with('only-version', domainError)
        .with(P.not(P.string), () => true)
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
    type: RecordEssaiResultType,
    description: [
      'Save what happened when you cooked a version: its rating and your notes. Fast and does ' +
        'not call the AI. If the rating is low and you want a suggested improvement, ask for a ' +
        'draft separately (see requestDraft).',
      '',
      '```graphql',
      'recordEssai(input: {',
      '  recipeId: "9f1c-a3b2"',
      '  versionNumber: 2',
      '  note: 4',
      '  remarks: "Still a touch too sweet, but the texture is spot on"',
      '}) {',
      '  version { number note }',
      '  promotionSuggested',
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
        .with('already-recorded', domainError)
        .with(P.not(P.string), (recorded) => recorded)
        .exhaustive()
    },
  }),
)
