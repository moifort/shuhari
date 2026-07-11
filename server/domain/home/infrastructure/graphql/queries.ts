import { HomeQuery } from '~/domain/home/query'
import { builder } from '~/domain/shared/graphql/builder'
import { HomeType } from './types'

builder.queryField('home', (t) =>
  t.field({
    type: HomeType,
    description: 'The home screen read model for the current user',
    resolve: (_root, _args, { userId }) => HomeQuery.load(userId),
  }),
)
