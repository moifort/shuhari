import { GraphQLError } from 'graphql'
import { PortabilityUseCase } from '~/domain/portability/use-case'
import { builder } from '~/domain/shared/graphql/builder'
import { ImportResultType } from './types'

builder.mutationField('importData', (t) =>
  t.field({
    type: ImportResultType,
    description: 'Replace all the current user records with the contents of a JSON envelope',
    args: { payload: t.arg.string({ required: true }) },
    resolve: async (_root, { payload }, { userId }) => {
      const result = await PortabilityUseCase.importAll(userId, payload)
      if ('error' in result) throw new GraphQLError(result.error)
      return result
    },
  }),
)
