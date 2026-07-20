/**
 * Generates the app icon with Nano Banana Pro (Gemini image model), as
 * `docs/collaboration.md` requires for every visual asset.
 *
 * Usage: GOOGLE_API_KEY=… bun scripts/generate-icon.ts <prompt-file> <output.png>
 */

// Marks the file as a module, without which tsc rejects the top-level awaits below.
export {}

const MODEL = 'gemini-3-pro-image-preview'

const [promptFile, output] = process.argv.slice(2)
if (!promptFile || !output) {
  console.error('usage: bun scripts/generate-icon.ts <prompt-file> <output.png>')
  process.exit(1)
}

const apiKey = process.env.GOOGLE_API_KEY
if (!apiKey) {
  console.error('GOOGLE_API_KEY is required')
  process.exit(1)
}

const prompt = await Bun.file(promptFile).text()

const response = await fetch(
  `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`,
  {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-goog-api-key': apiKey },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: { responseModalities: ['IMAGE'], imageConfig: { aspectRatio: '1:1' } },
    }),
  },
)

if (!response.ok) {
  console.error(`${response.status} ${response.statusText}`)
  console.error(await response.text())
  process.exit(1)
}

const body = await response.json()
const image = body.candidates?.[0]?.content?.parts?.find(
  (part: { inlineData?: unknown }) => part.inlineData,
)

if (!image) {
  console.error('no image in the response')
  console.error(JSON.stringify(body).slice(0, 800))
  process.exit(1)
}

await Bun.write(output, Buffer.from(image.inlineData.data, 'base64'))
console.log(`wrote ${output}`)
