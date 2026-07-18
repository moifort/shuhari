import { GraphQLError } from 'graphql'
import { PortabilityUseCase } from '~/domain/portability/use-case'
import { builder } from '~/domain/shared/graphql/builder'
import { ImportResultType } from './types'

builder.mutationField('importData', (t) =>
  t.field({
    type: ImportResultType,
    description:
      'Restore a backup. WARNING: this REPLACES everything you currently have with the contents ' +
      'of the JSON text (as produced by exportData). Returns a count of what was loaded.',
    args: {
      payload: t.arg.string({
        required: true,
        description: 'The backup as JSON text, exactly as exportData produced it',
      }),
    },
    resolve: async (_root, { payload }, { userId }) => {
      const result = await PortabilityUseCase.importAll(userId, payload)
      if ('error' in result) throw new GraphQLError(result.error)
      return result
    },
  }),
)
