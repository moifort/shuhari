import { describe, expect, test } from 'bun:test'
import { PANEL_HEIGHT, PANEL_WIDTH, panelHtml } from './panel'

describe('panelHtml', () => {
  const html = panelHtml({
    caption: 'Un carnet qui range\net qui classe',
    subtitle: 'Par type, par catégorie, en favoris.',
    screenshotPath: '/tmp/cuisine.png',
  })

  test('renders at the size the App Store expects', () => {
    expect(PANEL_WIDTH).toBe(1320)
    expect(PANEL_HEIGHT).toBe(2868)
    expect(html).toContain('width: 1320px')
    expect(html).toContain('height: 2868px')
  })

  test('turns the newline of a caption into a line break', () => {
    expect(html).toContain('Un carnet qui range<br>et qui classe')
  })

  test('points at the screenshot as a file URL', () => {
    expect(html).toContain('src="file:///tmp/cuisine.png"')
  })

  test('gives the text block a fixed height so every screen starts at the same offset', () => {
    expect(html).toContain('height: 26%')
    expect(html).toContain('height: 74%')
  })

  test('leaves the corners square, since a store screenshot is a plain rectangle', () => {
    expect(html).not.toContain('body { border-radius')
  })

  test('escapes copy that would otherwise break out of the markup', () => {
    const risky = panelHtml({
      caption: 'Fruits & <légumes>',
      subtitle: '"citron"',
      screenshotPath: '/tmp/a.png',
    })
    expect(risky).toContain('Fruits &amp; &lt;légumes&gt;')
    expect(risky).toContain('&quot;citron&quot;')
  })
})
