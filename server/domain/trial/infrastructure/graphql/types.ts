import { RecipeType, VersionType } from '~/domain/recipe/infrastructure/graphql/types'
import { builder } from '~/domain/shared/graphql/builder'
import { averageNote, highestNote } from '~/domain/trial/business-rules'
import type { Trial } from '../../types'

export const TrialType = builder.objectRef<Trial>('Trial').implement({
  description: 'One execution of a recipe version',
  fields: (t) => ({
    id: t.expose('id', { type: 'TrialId' }),
    recipeId: t.expose('recipeId', { type: 'RecipeId' }),
    versionNumber: t.expose('versionNumber', { type: 'VersionNumber' }),
    executedAt: t.expose('executedAt', { type: 'DateTime' }),
    note: t.expose('note', { type: 'Note' }),
    remarks: t.expose('remarks', { type: 'Remarks' }),
    photoUrl: t.string({
      nullable: true,
      description: 'Signed URL of the trial photo (null until photo storage is provisioned)',
      resolve: () => null,
    }),
  }),
})

// Satellite: the trials of a recipe (batched by recipeId via the loader).
builder.objectField(RecipeType, 'trials', (t) =>
  t.field({
    type: [TrialType],
    description: 'The recipe’s trial journal, most recent first',
    resolve: (recipe, _a, { loaders }) => loaders.trials.load(recipe.id).then((v) => v ?? []),
  }),
)

// Satellite: the recipe's best trial note across every version, from the same
// batched loader that backs the per-version aggregates (no extra reads).
builder.objectField(RecipeType, 'bestNote', (t) =>
  t.field({
    type: 'Note',
    nullable: true,
    description: 'The highest trial note the recipe ever scored, or null if never tried',
    resolve: async (recipe, _a, { loaders }) => {
      const trials = (await loaders.trials.load(recipe.id)) ?? []
      return highestNote(trials.map((trial) => trial.note))
    },
  }),
)

// Satellite: per-version trial aggregates, derived from the same batched loader.
builder.objectField(VersionType, 'trialCount', (t) =>
  t.int({
    description: 'How many trials ran against this version',
    resolve: async (version, _a, { loaders }) => {
      const trials = (await loaders.trials.load(version.recipeId)) ?? []
      return trials.filter((trial) => trial.versionNumber === version.number).length
    },
  }),
)

builder.objectField(VersionType, 'averageNote', (t) =>
  t.float({
    nullable: true,
    description: 'Mean trial note for this version, or null if never tried',
    resolve: async (version, _a, { loaders }) => {
      const trials = (await loaders.trials.load(version.recipeId)) ?? []
      return averageNote(
        trials.filter((trial) => trial.versionNumber === version.number).map((trial) => trial.note),
      )
    },
  }),
)
