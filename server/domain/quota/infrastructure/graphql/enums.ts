import { builder } from '~/domain/shared/graphql/builder'

export const PlanEnum = builder.enumType('Plan', {
  description:
    'What a cook is entitled to. The notebook itself is free and unlimited — the plan only ' +
    'decides how much AI comes with it.',
  values: {
    FREE: {
      value: 'free',
      description:
        'The free plan — unlimited recipes, a monthly allowance of AI calls, no URL import',
    },
    PREMIUM: {
      value: 'premium',
      description: 'The paid subscription — unlimited AI calls and the URL import',
    },
  } as const,
})
