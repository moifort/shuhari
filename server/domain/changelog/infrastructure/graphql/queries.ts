import { ChangelogQuery } from '~/domain/changelog/query'
import { builder } from '~/domain/shared/graphql/builder'
import { ChangelogEntryType } from './types'

builder.queryField('changelog', (t) =>
  t.field({
    type: [ChangelogEntryType],
    description: 'Application changelog, most recent versions first',
    resolve: () => ChangelogQuery.list(),
  }),
)
