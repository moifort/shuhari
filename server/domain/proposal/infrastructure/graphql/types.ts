import { RecipeType } from '~/domain/recipe/infrastructure/graphql/types'
import { builder } from '~/domain/shared/graphql/builder'
import type { Proposal, ProposalVar, VariationSuggestion } from '../../types'
import { ProposalRecommendationEnum } from './enums'

const ProposalVarType = builder.objectRef<ProposalVar>('ProposalVar').implement({
  description: 'A single proposed parameter change',
  fields: (t) => ({
    key: t.expose('key', { type: 'ParamKey' }),
    from: t.expose('from', { type: 'ParamValue', nullable: true }),
    to: t.expose('to', { type: 'ParamValue' }),
  }),
})

const VariationSuggestionType = builder
  .objectRef<VariationSuggestion>('VariationSuggestion')
  .implement({
    description: 'A suggested name and description when the AI recommends a variation',
    fields: (t) => ({
      title: t.expose('title', { type: 'RecipeTitle' }),
      description: t.exposeString('description'),
    }),
  })

export const ProposalType = builder.objectRef<Proposal>('Proposal').implement({
  description: 'An AI proposal for the next step of a recipe (presence == pending)',
  fields: (t) => ({
    recipeId: t.expose('recipeId', { type: 'RecipeId' }),
    versionNumber: t.expose('versionNumber', { type: 'VersionNumber' }),
    createdAt: t.expose('createdAt', { type: 'DateTime' }),
    vars: t.field({ type: [ProposalVarType], resolve: (p) => p.vars }),
    rationale: t.exposeString('rationale'),
    queued: t.exposeStringList('queued'),
    recommendation: t.expose('recommendation', { type: ProposalRecommendationEnum }),
    variation: t.field({
      type: VariationSuggestionType,
      nullable: true,
      resolve: (p) => p.variation ?? null,
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
