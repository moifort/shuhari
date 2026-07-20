import { EntitlementQuery } from '~/domain/entitlement/query'
import { QuotaQuery } from '~/domain/quota/query'
import { builder } from '~/domain/shared/graphql/builder'
import { QuotaType } from './types'

builder.queryField('quota', (t) =>
  t.field({
    type: QuotaType,
    description: [
      'Your AI allowance for the current month: the plan you are on, what you have spent, what ' +
        'is left and when it renews. Free plans get 3 imports and 5 iterations a month; Premium ' +
        'is unlimited and unlocks the URL import.',
      '',
      '```graphql',
      'quota {',
      '  plan',
      '  imports { used limit remaining }',
      '  iterations { used limit remaining }',
      '  renewsOn',
      '}',
      '```',
    ].join('\n'),
    resolve: async (_root, _args, { userId }) => ({
      plan: await EntitlementQuery.planOf(userId),
      quota: await QuotaQuery.current(userId),
    }),
  }),
)
