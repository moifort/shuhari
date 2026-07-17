import { IngredientInput, TmxSettingsInput } from '~/domain/recipe/infrastructure/graphql/inputs'
import { builder } from '~/domain/shared/graphql/builder'

// The user's inline-edited next-version draft, replacing the persisted AI draft
// when provided on accept. Mirrors CreateRecipeInput's content fields.
export const ProposalDraftInput = builder.inputType('ProposalDraftInput', {
  description:
    'An edited next-version draft. When provided, it FULLY REPLACES the persisted AI draft — send the COMPLETE next version, not a partial edit (omitted ingredients/steps wipe those lists).',
  fields: (t) => ({
    ingredients: t.field({
      type: [IngredientInput],
      required: true,
      description: 'The complete ingredient list of the next version (replaces the draft)',
    }),
    steps: t.field({
      type: ['StepText'],
      required: true,
      description: 'The complete step list of the next version (replaces the draft)',
    }),
    tmxSteps: t.field({
      type: [TmxSettingsInput],
      required: { list: false, items: false },
      description: 'Per-step Thermomix settings, aligned with steps (null = plain step)',
    }),
  }),
})
