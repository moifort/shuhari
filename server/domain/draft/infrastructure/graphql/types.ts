import { IngredientType, TmxSettingsType } from '~/domain/recipe/infrastructure/graphql/types'
import { builder } from '~/domain/shared/graphql/builder'
import type { Draft } from '../../types'

export const DraftType = builder.objectRef<Draft>('Draft').implement({
  description:
    'The AI’s suggestion for your next attempt, e.g. `"Less sugar, longer resting time"`. After ' +
    'a low-scoring essai, the AI reads your rating and notes and proposes a tweaked version. It ' +
    'is just a proposal shown on screen — nothing is saved until you accept it (see acceptDraft).',
  fields: (t) => ({
    versionNumber: t.expose('versionNumber', {
      type: 'VersionNumber',
      description:
        'The number this version would get if you accept it (the next one in the chain), e.g. `3`',
    }),
    changeSummary: t.exposeString('changeSummary', {
      description:
        'A one-line summary of what it changes, e.g. `"Less sugar, longer resting time"`',
    }),
    rationale: t.exposeString('rationale', {
      description:
        'The AI’s reasoning — why it thinks this change will help, based on your last notes, e.g. ' +
        '`"You noted it was too sweet, so cutting the sugar should balance it"`',
    }),
    ingredients: t.field({
      type: [IngredientType],
      description:
        'The complete ingredient list of the suggested version, e.g. `"Sugar — 80 g"` (not just ' +
        'what changed)',
      resolve: (d) => d.ingredients,
    }),
    steps: t.expose('steps', {
      type: ['StepText'],
      description:
        'The complete method of the suggested version, e.g. `"Rest the dough for 2 h"` (not just ' +
        'what changed)',
    }),
    tmxSteps: t.field({
      type: [TmxSettingsType],
      nullable: { list: false, items: true },
      description:
        'Per-step Thermomix settings aligned with steps, e.g. `"10 min / 100°C / speed 2"` ' +
        '(`null` = plain step; `[]` if not tmx)',
      resolve: (d) => d.tmxSteps,
    }),
  }),
})
