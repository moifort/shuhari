import { ChangelogQuery } from '~/domain/changelog/query'
import { builder } from '~/domain/shared/graphql/builder'
import { ChangelogEntryType } from './types'

builder.queryField('changelog', (t) =>
  t.field({
    type: [ChangelogEntryType],
    description:
      'The app’s "What’s new" list — one entry per release, newest first. Feeds the changelog ' +
      'screen. For example: { version: "1.2", date: "2026-07-18…", notes: ["Faster recipe ' +
      'imports", "Fixed a crash when exporting"] }, then the 1.1 entry, and so on.',
    resolve: () => ChangelogQuery.list(),
  }),
)
