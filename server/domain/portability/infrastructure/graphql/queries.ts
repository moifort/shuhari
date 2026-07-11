import { PortabilityUseCase } from '~/domain/portability/use-case'
import { builder } from '~/domain/shared/graphql/builder'

builder.queryField('exportData', (t) =>
  t.string({
    description: 'JSON-encoded export of every record belonging to the current user',
    resolve: async (_root, _args, { userId }) => {
      const envelope = await PortabilityUseCase.exportAll(userId)
      return JSON.stringify(envelope)
    },
  }),
)
