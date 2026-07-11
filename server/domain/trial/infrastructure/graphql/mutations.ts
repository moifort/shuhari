import { GraphQLError } from 'graphql'
import { builder } from '~/domain/shared/graphql/builder'
import type { RecordTrialResult } from '~/domain/trial/use-case'
import { TrialUseCase } from '~/domain/trial/use-case'
import { RecordTrialInput } from './inputs'
import { TrialType } from './types'

const RecordTrialResultType = builder.objectRef<RecordTrialResult>('RecordTrialResult').implement({
  description: 'Outcome of recording a trial',
  fields: (t) => ({
    trial: t.field({ type: TrialType, resolve: (r) => r.trial }),
    promotionSuggested: t.boolean({
      description: 'True when this trial qualifies its version for promotion',
      resolve: (r) => r.promotionSuggested,
    }),
  }),
})

builder.mutationField('recordTrial', (t) =>
  t.field({
    type: RecordTrialResultType,
    description: 'Record a trial (fast, no AI). Ask for a proposal separately if the note is low.',
    args: { input: t.arg({ type: RecordTrialInput, required: true }) },
    resolve: async (_root, { input }, { userId }) => {
      const result = await TrialUseCase.record(userId, {
        recipeId: input.recipeId,
        versionNumber: input.versionNumber,
        note: input.note,
        remarks: input.remarks,
        enteredParams: input.realParams,
        photoPath: null,
      })
      if (result === 'not-found')
        throw new GraphQLError('Recipe or version not found', { extensions: { code: 'NOT_FOUND' } })
      return result
    },
  }),
)
