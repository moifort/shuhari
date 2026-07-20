import { builder } from '~/domain/shared/graphql/builder'
import { AccountUseCase } from '~/system/account/use-case'

builder.mutationField('deleteAccount', (t) =>
  t.field({
    type: 'Boolean',
    description: [
      'Delete your account and everything the app holds on you: every recipe, every version, ' +
        'every attempt, your AI allowance and your entitlement. IRREVERSIBLE and immediate — ' +
        'there is no grace period and no way back. Export first if you want a copy ' +
        '(see exportData). Returns `true` once it is done.',
      '',
      'This does NOT cancel an App Store subscription: only the subscriber can, from the ' +
        'App Store settings. Deleting the account while a subscription runs leaves it billing.',
      '',
      '```graphql',
      'deleteAccount',
      '```',
    ].join('\n'),
    resolve: async (_root, _args, { userId }) => {
      await AccountUseCase.remove(userId)
      return true
    },
  }),
)
