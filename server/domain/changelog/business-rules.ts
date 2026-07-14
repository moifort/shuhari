import { ChangelogVersion } from '~/domain/changelog/primitives'

const headingPattern = /^##\s+(.+?)\s*$/
const bulletPattern = /^[-*]\s+(.+?)\s*$/
const datedPattern = /^(\d{4})\.(\d{2})\.(\d{2})$/

const parseDate = (heading: string) => {
  const match = headingPattern.exec(heading.trim())
  if (!match) return null
  const dated = datedPattern.exec(match[1])
  if (!dated) return null
  return new Date(Date.UTC(Number(dated[1]), Number(dated[2]) - 1, Number(dated[3])))
}

const parseHeading = (heading: string) => {
  const match = headingPattern.exec(heading.trim())
  return match ? match[1] : null
}

const isHeading = (line: string) => line.trimStart().startsWith('## ')

// Split the markdown into sections at each `## ` heading, then turn each section
// (heading line + the bullet lines up to the next heading) into an entry.
export const parseChangelog = (markdown: string) => {
  const lines = markdown.split(/\r?\n/).map((raw) => raw.trimEnd())
  const headings = lines.flatMap((line, index) => (isHeading(line) ? [index] : []))
  return headings.flatMap((start, i) => {
    const heading = parseHeading(lines[start])
    if (!heading) return []
    const end = headings[i + 1] ?? lines.length
    const notes = lines.slice(start + 1, end).flatMap((line) => {
      const bullet = bulletPattern.exec(line)
      return bullet ? [bullet[1]] : []
    })
    return [{ version: ChangelogVersion(heading), date: parseDate(lines[start]), notes }]
  })
}
