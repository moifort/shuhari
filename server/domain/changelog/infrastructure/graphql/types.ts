import type { ChangelogEntry } from '~/domain/changelog/types'
import { builder } from '~/domain/shared/graphql/builder'

export const ChangelogEntryType = builder.objectRef<ChangelogEntry>('ChangelogEntry').implement({
  description: 'A single version section of the application changelog',
  fields: (t) => ({
    version: t.exposeString('version'),
    date: t.expose('date', { type: 'DateTime', nullable: true }),
    notes: t.exposeStringList('notes'),
  }),
})
