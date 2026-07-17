import {
  IngredientType,
  RecipeType,
  TmxSettingsType,
} from '~/domain/recipe/infrastructure/graphql/types'
import { builder } from '~/domain/shared/graphql/builder'
import type { Proposal } from '../../types'

export const ProposalType = builder.objectRef<Proposal>('Proposal').implement({
  description: 'An AI proposal for the next version of a recipe (presence == pending)',
  fields: (t) => ({
    recipeId: t.expose('recipeId', { type: 'RecipeId' }),
    versionNumber: t.expose('versionNumber', { type: 'VersionNumber' }),
    createdAt: t.expose('createdAt', { type: 'DateTime' }),
    changeSummary: t.exposeString('changeSummary', {
      description: 'A short human summary of what the next version changes',
    }),
    rationale: t.exposeString('rationale'),
    ingredients: t.field({
      type: [IngredientType],
      description: 'The full ingredient list of the drafted next version',
      resolve: (p) => p.ingredients,
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
      resolve: (p) => p.tmxSteps,
    }),
  }),
})

// Satellite: the active proposal for a recipe's current version (batched loader).
builder.objectField(RecipeType, 'pendingProposal', (t) =>
  t.field({
    type: ProposalType,
    nullable: true,
    description: 'The AI proposal awaiting a decision, if any',
    resolve: (recipe, _a, { loaders }) =>
      loaders.proposal
        .load({ recipeId: recipe.id, versionNumber: recipe.currentVersion })
        .then((p) => p ?? null),
  }),
)
