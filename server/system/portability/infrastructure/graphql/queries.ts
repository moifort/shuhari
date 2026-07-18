import { builder } from '~/domain/shared/graphql/builder'
import { PortabilityUseCase } from '~/system/portability/use-case'

builder.queryField('exportData', (t) =>
  t.string({
    description: [
      'Download all your data as one JSON text — a full backup of every recipe and version you ' +
        'own (e.g. your `"Grandma’s lasagna"` and all its essais). Pair it with importData to ' +
        'move or restore your library.',
      '',
      '```graphql',
      'query {',
      '  exportData',
      '}',
      '```',
    ].join('\n'),
    resolve: async (_root, _args, { userId }) => {
      const envelope = await PortabilityUseCase.exportAll(userId)
      return JSON.stringify(envelope)
    },
  }),
)
