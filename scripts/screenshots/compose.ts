/// Renders every panel to a PNG the App Store accepts, by driving headless Chrome over the
/// HTML template. Chrome is used rather than an image library because the design was authored
/// in CSS and stays retouchable there.

import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { PANEL_HEIGHT, PANEL_WIDTH, panelHtml } from './panel'

const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'

const [rawDir, outDir] = process.argv.slice(2)
if (!rawDir || !outDir) {
  console.error('usage: bun scripts/screenshots/compose.ts <raw-dir> <out-dir>')
  process.exit(1)
}

const root = resolve(import.meta.dir, '../..')
const panels: { screen: string; caption: string; subtitle: string }[] = JSON.parse(
  readFileSync(resolve(root, 'scripts/screenshots/panels.json'), 'utf8'),
)

mkdirSync(resolve(outDir), { recursive: true })
const work = resolve(outDir, '.html')
mkdirSync(work, { recursive: true })

for (const [index, panel] of panels.entries()) {
  const screenshotPath = resolve(rawDir, `${panel.screen}.png`)
  const htmlPath = resolve(work, `${panel.screen}.html`)
  // The order shown on the listing is the alphabetical order of the file names.
  const output = resolve(outDir, `${index + 1}-${panel.screen}.png`)

  writeFileSync(htmlPath, panelHtml({ ...panel, screenshotPath }))

  const chrome = Bun.spawnSync([
    CHROME,
    '--headless=new',
    '--disable-gpu',
    '--hide-scrollbars',
    '--force-device-scale-factor=1',
    `--window-size=${PANEL_WIDTH},${PANEL_HEIGHT}`,
    `--screenshot=${output}`,
    `file://${htmlPath}`,
  ])

  if (chrome.exitCode !== 0) {
    console.error(chrome.stderr.toString())
    process.exit(1)
  }
  console.log(`composed ${output}`)
}
