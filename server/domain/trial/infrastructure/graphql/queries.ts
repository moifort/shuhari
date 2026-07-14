import { match } from 'ts-pattern'
import { builder } from '~/domain/shared/graphql/builder'
import { TrialQuery } from '~/domain/trial/query'
import { TrialType } from './types'

builder.queryField('trial', (t) =>
  t.field({
    type: TrialType,
    nullable: true,
    description: 'A single trial by id',
    args: { id: t.arg({ type: 'TrialId', required: true }) },
    resolve: async (_root, { id }, { userId }) => {
      const trial = await TrialQuery.byId(userId, id)
      return match(trial)
        .with('not-found', () => null)
        .otherwise((found) => found)
    },
  }),
)
