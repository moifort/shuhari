import { IngredientInput, TmxSettingsInput } from '~/domain/recipe/infrastructure/graphql/inputs'
import { builder } from '~/domain/shared/graphql/builder'

// The full next-version draft the client sends back on accept. It carries the
// AI's (possibly user-edited) content plus its summary and rationale — send the
// COMPLETE next version, never a partial edit.
export const DraftInput = builder.inputType('DraftInput', {
  description:
    'A complete next-version draft to accept as an iteration. Send the FULL next version (omitted ingredients/steps wipe those lists).',
  fields: (t) => ({
    changeSummary: t.field({
      type: 'String',
      required: true,
      description: 'A short human summary of what the next version changes',
    }),
    rationale: t.field({
      type: 'String',
      required: true,
      description: 'The reasoning behind the change',
    }),
    ingredients: t.field({
      type: [IngredientInput],
      required: true,
      description: 'The complete ingredient list of the next version',
    }),
    steps: t.field({
      type: ['StepText'],
      required: true,
      description: 'The complete step list of the next version',
    }),
    tmxSteps: t.field({
      type: [TmxSettingsInput],
      required: { list: false, items: false },
      description: 'Per-step Thermomix settings, aligned with steps (null = plain step)',
    }),
  }),
})
