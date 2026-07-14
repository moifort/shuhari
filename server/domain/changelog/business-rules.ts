import { ChangelogVersion } from '~/domain/changelog/primitives'
import type { ChangelogEntry } from '~/domain/changelog/types'

const headingPattern = /^##\s+(.+?)\s*$/
const bulletPattern = /^[-*]\s+(.+?)\s*$/
const datedPattern = /^(\d{4})\.(\d{2})\.(\d{2})$/

const parseDate = (heading: string): Date | null => {
  const match = headingPattern.exec(heading.trim())
  if (!match) return null
  const dated = datedPattern.exec(match[1])
  if (!dated) return null
  return new Date(Date.UTC(Number(dated[1]), Number(dated[2]) - 1, Number(dated[3])))
}

const parseHeading = (heading: string): string | null => {
  const match = headingPattern.exec(heading.trim())
  return match ? match[1] : null
}

const isHeading = (line: string) => line.trimStart().startsWith('## ')

type ParseState = { entries: ChangelogEntry[]; current: ChangelogEntry | null }

export const parseChangelog = (markdown: string): ChangelogEntry[] => {
  const { entries, current } = markdown.split(/\r?\n/).reduce<ParseState>(
    (state, raw) => {
      const line = raw.trimEnd()
      if (isHeading(line)) {
        const entries = state.current ? [...state.entries, state.current] : state.entries
        const heading = parseHeading(line)
        return heading
          ? {
              entries,
              current: { version: ChangelogVersion(heading), date: parseDate(line), notes: [] },
            }
          : { entries, current: null }
      }
      if (!state.current) return state
      const bullet = bulletPattern.exec(line)
      return bullet
        ? { ...state, current: { ...state.current, notes: [...state.current.notes, bullet[1]] } }
        : state
    },
    { entries: [], current: null },
  )
  return current ? [...entries, current] : entries
}
