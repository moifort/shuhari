import { IngredientType, TmxSettingsType } from '~/domain/recipe/infrastructure/graphql/types'
import { builder } from '~/domain/shared/graphql/builder'
import type { Draft } from '../../types'

export const DraftType = builder.objectRef<Draft>('Draft').implement({
  description: 'An ephemeral AI draft of the next version of a recipe (never persisted)',
  fields: (t) => ({
    versionNumber: t.expose('versionNumber', { type: 'VersionNumber' }),
    changeSummary: t.exposeString('changeSummary', {
      description: 'A short human summary of what the next version changes',
    }),
    rationale: t.exposeString('rationale'),
    ingredients: t.field({
      type: [IngredientType],
      description: 'The full ingredient list of the drafted next version',
      resolve: (d) => d.ingredients,
    }),
    steps: t.expose('steps', {
      type: ['StepText'],
      description: 'The full step list of the drafted next version',
    }),
    tmxSteps: t.field({
      type: [TmxSettingsType],
      nullable: { list: false, items: true },
      description:
        'Per-step Thermomix settings aligned with steps (null = plain step; [] if not tmx)',
      resolve: (d) => d.tmxSteps,
    }),
  }),
})
