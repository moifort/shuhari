/// One App Store panel: an orange stage, a caption, and the screenshot below it.
/// Rendered to PNG by Chrome, so the whole design lives in CSS and is retouched there.

/// The 6.5-inch canvas the App Store listing uses. Every other iPhone size is derived
/// from it, so it is the only one the pipeline produces.
export const PANEL_WIDTH = 1242
export const PANEL_HEIGHT = 2688

/// Type sizes are expressed against the canvas width rather than in fixed pixels: the
/// same template then holds its proportions if the store ever asks for another size,
/// instead of quietly shrinking the copy relative to the frame.
const scaled = (atFullWidth: number) => Math.round((atFullWidth / 1320) * PANEL_WIDTH)

export type Panel = { caption: string; subtitle: string; screenshotPath: string }

const escapeHtml = (text: string) =>
  text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')

export const panelHtml = ({ caption, subtitle, screenshotPath }: Panel) => `<!DOCTYPE html>
<html lang="fr">
  <head>
    <meta charset="utf-8" />
    <style>
      * { margin: 0; padding: 0; box-sizing: border-box; }
      body {
        width: ${PANEL_WIDTH}px;
        height: ${PANEL_HEIGHT}px;
        overflow: hidden;
        display: flex;
        flex-direction: column;
        align-items: center;
        /* No rounded corners: an App Store screenshot is a plain rectangle. The
           rounding seen while designing belonged to the browser preview only. */
        background: linear-gradient(160deg, #FF9F43 0%, #FF5F6D 100%);
        font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif;
      }
      /* Fixed height, not flex: a one-line caption must not shift the screenshot
         up relative to the other panels, or the set stops lining up. */
      .head {
        height: 26%;
        width: 100%;
        padding: 0 ${scaled(80)}px;
        display: flex;
        flex-direction: column;
        justify-content: center;
        text-align: center;
      }
      .caption {
        color: #fff;
        font-size: ${scaled(78)}px;
        font-weight: 700;
        line-height: 1.22;
        letter-spacing: ${scaled(-1.2)}px;
      }
      .subtitle {
        margin-top: ${scaled(30)}px;
        color: rgba(255, 255, 255, 0.88);
        font-size: ${scaled(40)}px;
        line-height: 1.32;
      }
      .device {
        width: 78%;
        height: 74%;
        overflow: hidden;
        border: ${scaled(17)}px solid rgba(255, 255, 255, 0.94);
        border-bottom: 0;
        border-radius: ${scaled(85)}px ${scaled(85)}px 0 0;
        box-shadow: 0 ${scaled(40)}px ${scaled(110)}px rgba(0, 0, 0, 0.3);
      }
      .device img {
        width: 100%;
        height: 100%;
        display: block;
        object-fit: cover;
        object-position: top center;
      }
    </style>
  </head>
  <body>
    <div class="head">
      <div class="caption">${escapeHtml(caption).replace(/\n/g, '<br>')}</div>
      <div class="subtitle">${escapeHtml(subtitle)}</div>
    </div>
    <div class="device"><img src="file://${screenshotPath}" alt="" /></div>
  </body>
</html>
`
