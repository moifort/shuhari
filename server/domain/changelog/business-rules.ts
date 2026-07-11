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

export const parseChangelog = (markdown: string): ChangelogEntry[] => {
  const entries: ChangelogEntry[] = []
  const lines = markdown.split(/\r?\n/)

  let current: ChangelogEntry | null = null

  for (const raw of lines) {
    const line = raw.trimEnd()
    if (isHeading(line)) {
      if (current) entries.push(current)
      const heading = parseHeading(line)
      if (!heading) {
        current = null
        continue
      }
      current = {
        version: ChangelogVersion(heading),
        date: parseDate(line),
        notes: [],
      }
      continue
    }
    if (!current) continue
    const bullet = bulletPattern.exec(line)
    if (bullet) current.notes.push(bullet[1])
  }

  if (current) entries.push(current)
  return entries
}
