import { builder } from '~/domain/shared/graphql/builder'
import { ChangelogQuery } from '~/system/changelog/query'
import { ChangelogEntryType } from './types'

builder.queryField('changelog', (t) =>
  t.field({
    type: [ChangelogEntryType],
    description: [
      'The app’s "What’s new" list — one entry per release, newest first. Feeds the changelog ' +
        'screen. For example the `"1.2"` entry with notes `"Faster recipe imports"` and ' +
        '`"Fixed a crash when exporting"`, then the `"1.1"` entry, and so on.',
      '',
      '```graphql',
      'changelog {',
      '  version',
      '  date',
      '  notes',
      '}',
      '```',
    ].join('\n'),
    resolve: () => ChangelogQuery.list(),
  }),
)
