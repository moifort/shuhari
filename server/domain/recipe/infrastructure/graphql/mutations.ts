import { match, P } from 'ts-pattern'
import { toTmxSettings } from '~/domain/recipe/business-rules'
import { RecipeCommand, type RecordEssaiResult } from '~/domain/recipe/command'
import { RecipeUseCase } from '~/domain/recipe/use-case'
import { builder } from '~/domain/shared/graphql/builder'
import { domainError } from '~/domain/shared/graphql/errors'
import { CreateRecipeInput, RecordEssaiInput, UpdateRecipeInput } from './inputs'
import { RecipeType, VersionType } from './types'

const RecordEssaiResultType = builder.objectRef<RecordEssaiResult>('RecordEssaiResult').implement({
  description: 'Outcome of recording an essai onto a version',
  fields: (t) => ({
    version: t.field({ type: VersionType, resolve: (r) => r.version }),
    promotionSuggested: t.boolean({
      description: 'True when this essai qualifies its version for promotion',
      resolve: (r) => r.promotionSuggested,
    }),
  }),
})

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
        .with('not-found', domainError)
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
    description: 'Discard the pending essai — delete its untried version',
    args: {
      recipeId: t.arg({ type: 'RecipeId', required: true }),
      versionNumber: t.arg({ type: 'VersionNumber', required: true }),
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
    description: 'Delete a recipe and all its versions',
    args: { id: t.arg({ type: 'RecipeId', required: true }) },
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
    description:
      'Record an essai onto a version (fast, no AI). Ask for a draft separately if the note is low.',
    args: { input: t.arg({ type: RecordEssaiInput, required: true }) },
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
