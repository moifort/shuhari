import { describe, expect, test } from 'bun:test'
import { marketingVersion, releaseNotes } from './release-notes'

const changelog = `# Journal des modifications

Toutes les évolutions notables de Shuhari, la plus récente en premier.

## 1.1 (2026.09.01)

### New

- Une nouveauté de la 1.1.

## 1.0 (2026.08.01)

### New

- Première version de Shuhari.
- Import par photo.

### Fixes

- Un correctif.
`

describe('marketingVersion', () => {
  test('reads the version out of the Xcode project', () => {
    const pbxproj = `
        CURRENT_PROJECT_VERSION = 4;
        MARKETING_VERSION = 1.0;
    `
    expect(marketingVersion(pbxproj)).toBe('1.0')
  })

  test('reports a project with no version rather than guessing one', () => {
    expect(marketingVersion('CURRENT_PROJECT_VERSION = 4;')).toBe('not-found')
  })
})

describe('releaseNotes', () => {
  test('returns the bullets of the asked version, headings stripped', () => {
    expect(releaseNotes(changelog, '1.0')).toBe(
      'Première version de Shuhari.\nImport par photo.\nUn correctif.',
    )
  })

  test('stops at the next version rather than swallowing the whole file', () => {
    expect(releaseNotes(changelog, '1.1')).toBe('Une nouveauté de la 1.1.')
  })

  test('strips the markdown emphasis the App Store would show literally', () => {
    const emphasised = '## 1.0 (2026.08.01)\n\n- Deux types : **Plat** et **Thermomix**.\n'
    expect(releaseNotes(emphasised, '1.0')).toBe('Deux types : Plat et Thermomix.')
  })

  test('refuses a changelog still holding an Unreleased section', () => {
    const pending = '## Unreleased\n\n- Pas encore daté.\n\n## 1.0 (2026.08.01)\n\n- Sortie.\n'
    expect(releaseNotes(pending, '1.0')).toBe('unreleased')
  })

  test('refuses a version that the changelog never mentions', () => {
    expect(releaseNotes(changelog, '9.9')).toBe('version-not-found')
  })

  test('does not mistake 1.1 for a prefix of 1.10', () => {
    const both = '## 1.10 (2026.10.01)\n\n- La dix.\n\n## 1.1 (2026.09.01)\n\n- La un.\n'
    expect(releaseNotes(both, '1.1')).toBe('La un.')
  })
})
