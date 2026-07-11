import { builder } from '~/domain/shared/graphql/builder'

export const ProposalRecommendationEnum = builder.enumType('ProposalRecommendation', {
  description: 'Whether the AI recommends iterating the recipe or spinning off a variation',
  values: {
    ITERATION: { value: 'iteration' },
    VARIATION: { value: 'variation' },
  } as const,
})
