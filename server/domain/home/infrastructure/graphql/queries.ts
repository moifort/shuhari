import { HomeQuery } from '~/domain/home/query'
import { builder } from '~/domain/shared/graphql/builder'
import { HomeType } from './types'

builder.queryField('home', (t) =>
  t.field({
    type: HomeType,
    description: [
      'Everything the home screen needs in one shot: the attempts waiting to be cooked ' +
        '(toTest), your whole library, and your latest cooked essais. For example, toTest might ' +
        'hold `"Grandma’s lasagna v3"` while recentEssais shows the risotto you rated yesterday.',
      '',
      '```graphql',
      'home {',
      '  toTest { id title toTest { number } }',
      '  recentEssais { number note remarks }',
      '}',
      '```',
    ].join('\n'),
    resolve: (_root, _args, { userId }) => HomeQuery.load(userId),
  }),
)
