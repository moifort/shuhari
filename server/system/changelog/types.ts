import type { Brand } from 'ts-brand'

export type ChangelogVersion = Brand<string, 'ChangelogVersion'>

export type ChangelogEntry = {
  version: ChangelogVersion
  date?: Date
  notes: string[]
}
