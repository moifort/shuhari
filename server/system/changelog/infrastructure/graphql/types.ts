import { builder } from '~/domain/shared/graphql/builder'
import type { ChangelogEntry } from '~/system/changelog/types'

export const ChangelogEntryType = builder.objectRef<ChangelogEntry>('ChangelogEntry').implement({
  description:
    'One release in the app’s "What’s new" list — the changes shipped in a given version of the ' +
    'app, e.g. `"1.2"` with "Faster recipe imports"',
  fields: (t) => ({
    version: t.exposeString('version', {
      description: 'The app version these notes are for, e.g. `"1.2"`',
    }),
    date: t.expose('date', {
      type: 'DateTime',
      nullable: true,
      description:
        'When that version was released, e.g. `"2026-07-18T00:00:00.000Z"` (`null` for a release ' +
        'not yet dated)',
    }),
    notes: t.exposeStringList('notes', {
      description:
        'The list of changes in this release, one line each, ready to show to the user, e.g. ' +
        '`"Faster recipe imports"` then `"Fixed a crash when exporting"`',
    }),
  }),
})
