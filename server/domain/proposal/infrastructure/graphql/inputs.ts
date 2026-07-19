import { IngredientInput, TmxSettingsInput } from '~/domain/recipe/infrastructure/graphql/inputs'
import { builder } from '~/domain/shared/graphql/builder'

// The full next-version proposal the client sends back on accept. It carries the
// AI's (possibly user-edited) content plus its summary, rationale and the version it
// iterates on — send the COMPLETE next version, never a partial edit.
export const ProposalInput = builder.inputType('ProposalInput', {
  description:
    'A complete next-version proposal to accept as an iteration, e.g. the AI’s ' +
    '`"Less sugar, longer resting time"` proposal. Send the FULL next version (omitted ' +
    'ingredients/steps wipe those lists).',
  fields: (t) => ({
    basedOn: t.field({
      type: 'VersionNumber',
      required: true,
      description:
        'The version this iterates on — echo back the `basedOn` from the proposal, e.g. `2`',
    }),
    changeSummary: t.field({
      type: 'String',
      required: true,
      description: 'A short human summary of what the next version changes, e.g. `"Less sugar"`',
    }),
    rationale: t.field({
      type: 'String',
      required: true,
      description: 'The reasoning behind the change, e.g. `"You noted it was too sweet"`',
    }),
    ingredients: t.field({
      type: [IngredientInput],
      required: true,
      description: 'The complete ingredient list of the next version, e.g. `"Sugar — 80 g"`',
    }),
    steps: t.field({
      type: ['StepText'],
      required: true,
      description: 'The complete step list of the next version, e.g. `"Rest the dough for 2 h"`',
    }),
    tmxSteps: t.field({
      type: [TmxSettingsInput],
      required: { list: false, items: false },
      description:
        'Per-step Thermomix settings, aligned with steps, e.g. `"10 min / 100°C / speed 2"` ' +
        '(`null` = plain step)',
    }),
  }),
})
