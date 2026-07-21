import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

/// The version the Xcode project ships. A tag that disagrees with it would upload a build
/// labelled with someone else's version number, which App Store Connect accepts silently.
export const marketingVersion = (pbxproj: string) =>
  pbxproj.match(/MARKETING_VERSION = ([^;]+);/)?.[1]?.trim() ?? 'not-found'

/// The bullets of one released version, as plain text for the App Store's "What's New" field.
/// Section headings (`### New`, `### Fixes`) are dropped: the store shows one flat list, and a
/// stray `###` would be printed literally. So would `**bold**`, hence the emphasis stripping.
export const releaseNotes = (markdown: string, version: string) => {
  if (/^## Unreleased\s*$/m.test(markdown)) return 'unreleased' as const

  // The word boundary is what keeps `1.1` from matching the `1.10` section above it.
  const heading = new RegExp(`^## ${version.replace(/\./g, '\\.')}\\b.*$`, 'm')
  const start = markdown.search(heading)
  if (start === -1) return 'version-not-found' as const

  const rest = markdown.slice(start).split('\n').slice(1)
  const nextVersion = rest.findIndex((line) => line.startsWith('## '))
  const section = nextVersion === -1 ? rest : rest.slice(0, nextVersion)

  return section
    .filter((line) => line.startsWith('- '))
    .map((line) => line.slice(2).replace(/\*\*/g, '').trim())
    .join('\n')
}

/// Two changelogs, two audiences: the French one is what the App Store shows a cook,
/// the English one is what the repository shows a developer. Both are versioned at the
/// same moment, so both are guarded.
const CHANGELOGS = { fr: 'CHANGELOG.fr.md', en: 'CHANGELOG.md' } as const
type Locale = keyof typeof CHANGELOGS

const [command, version, locale = 'fr'] = process.argv.slice(2)
if (command) {
  const root = resolve(import.meta.dir, '..')
  const notesOf = (which: Locale) =>
    releaseNotes(readFileSync(resolve(root, CHANGELOGS[which]), 'utf8'), version)

  if (command === 'guard') {
    const project = readFileSync(resolve(root, 'ios/Shuhari.xcodeproj/project.pbxproj'), 'utf8')
    const marketing = marketingVersion(project)
    if (marketing !== version) {
      console.error(`tag says ${version}, MARKETING_VERSION says ${marketing}`)
      process.exit(1)
    }
    for (const which of Object.keys(CHANGELOGS) as Locale[]) {
      const notes = notesOf(which)
      if (notes === 'unreleased') {
        console.error(
          `${CHANGELOGS[which]} still has an "## Unreleased" section — version it first`,
        )
        process.exit(1)
      }
      if (notes === 'version-not-found') {
        console.error(`${CHANGELOGS[which]} has no "## ${version}" section`)
        process.exit(1)
      }
    }
    console.log(`release ${version} is ready`)
  }

  if (command === 'notes') {
    if (!(locale in CHANGELOGS)) {
      console.error(`unknown locale '${locale}' — expected one of ${Object.keys(CHANGELOGS)}`)
      process.exit(1)
    }
    const notes = notesOf(locale as Locale)
    if (notes === 'unreleased' || notes === 'version-not-found') {
      console.error(`cannot produce release notes: ${notes}`)
      process.exit(1)
    }
    console.log(notes)
  }
}
