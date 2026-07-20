import { match, P } from 'ts-pattern'
import { EntitlementQuery } from '~/domain/entitlement/query'
import { EntitlementUseCase } from '~/domain/entitlement/use-case'
import { builder } from '~/domain/shared/graphql/builder'
import { domainError } from '~/domain/shared/graphql/errors'
import { EntitlementType } from './types'

builder.mutationField('syncEntitlement', (t) =>
  t.field({
    type: EntitlementType,
    description: [
      'Hand over a transaction the App Store signed for you — after a purchase, after a restore, ' +
        'and on every launch while a subscription is running. The signature is verified against ' +
        'Apple’s root certificates and the purchase must carry your `appAccountToken`, so this ' +
        'is what grants Premium: nothing else does.',
      '',
      'Answers `INVALID_TRANSACTION` when the signature does not check out, and ' +
        '`TRANSACTION_NOT_YOURS` when the purchase belongs to another account.',
      '',
      '```graphql',
      'syncEntitlement(signedTransaction: "eyJhbGciOi...") {',
      '  plan',
      '  expiresOn',
      '}',
      '```',
    ].join('\n'),
    args: {
      signedTransaction: t.arg.string({
        required: true,
        description:
          'The JWS representation of the StoreKit transaction, e.g. the `jwsRepresentation` of ' +
          'a verified entitlement',
      }),
    },
    resolve: async (_root, { signedTransaction }, { userId }) => {
      const result = await EntitlementUseCase.sync(userId, signedTransaction)
      return match(result)
        .with('invalid-transaction', domainError)
        .with('transaction-not-yours', domainError)
        .with(P.not(P.string), async (entitlement) => ({
          plan: await EntitlementQuery.planOf(userId),
          appAccountToken: entitlement.appAccountToken as string,
          entitlement,
        }))
        .exhaustive()
    },
  }),
)
