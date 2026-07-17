import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'

const root = resolve(import.meta.dir, '..')
// CHANGELOG.md is the English source; CHANGELOG.fr.md is the French copy served to the app.
const source = resolve(root, 'CHANGELOG.fr.md')
const target = resolve(root, 'server/system/changelog-content.ts')

const markdown = readFileSync(source, 'utf8')

const banner =
  '// Generated from CHANGELOG.fr.md by scripts/generate-changelog-asset.ts. Do not edit.\n'
const body = `export const changelogMarkdown: string = ${JSON.stringify(markdown)}\n`

mkdirSync(dirname(target), { recursive: true })
writeFileSync(target, banner + body)
