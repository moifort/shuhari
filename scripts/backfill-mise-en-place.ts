// Write the mise en place onto the cooked versions stored before the section
// existed — the ones migration 12 left with an empty list. A dev tool, run by hand
// and on purpose: the notebook's own rule is that nothing rewrites a version behind
// the cook's back (see docs/business-rules.md, "The mise en place comes before the
// steps"), and this is the cook choosing to have every old recipe read the way a
// new one does, in one go, rather than iteration by iteration.
//
// Usage:
//   bun scripts/backfill-mise-en-place.ts [--dry-run] [--limit N] [--recipe <id>]
//
//   --dry-run   list the versions that would be written, call nothing, write nothing
//   --limit N   stop after N versions written (a first run on a handful)
//   --recipe    one recipe's lineage only
//
// It needs Google application-default credentials for the production project
// (`gcloud auth application-default login`). The Gemini key is read from
// NITRO_GOOGLE_API_KEY when .env carries it, and from Secret Manager otherwise —
// the same secret the deployed function reads, so nothing has to be copied around.
//
// What it writes, and nothing else: `content.miseEnPlace` of each version whose
// list is empty and whose steps are not. The mise en place restates the recipe, so
// it is written IN PLACE — no version is created, `updatedAt` is left alone (the
// cook wrote nothing), and a version already carrying one is never touched, which
// makes a re-run cost only the versions the last one did not reach. A coffee
// readies nothing and is skipped. The prompt is the same instruction the three
// cooking prompts share (`miseEnPlaceSchemaProperty`), asked on its own.
//
// Not used by the server, which reaches Gemini through Nitro (`~/system/ai`): this
// one runs outside it, where `$fetch` and `useRuntimeConfig()` do not exist.
import { getApps, initializeApp } from 'firebase-admin/app'
import { type DocumentData, getFirestore } from 'firebase-admin/firestore'
import { GoogleAuth } from 'google-auth-library'
import { RECIPE_MAX } from '../server/domain/recipe/limits'
import { miseEnPlaceSchemaProperty } from '../server/system/ai/schema'

const PROJECT_ID = 'shuhari-polyforms'
const GEMINI_API_URL =
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent'
// The same cap the AI parse layer puts on every list it reads.
const MAX_LINES = 100
// Between two calls — Flash's free tier is rate-limited per minute, and a backfill
// is in no hurry.
const PAUSE_MS = 1500

// ---- Arguments ---------------------------------------------------------------

const args = process.argv.slice(2)
const dryRun = args.includes('--dry-run')
const flag = (name: string) => {
  const at = args.indexOf(name)
  return at >= 0 ? args[at + 1] : undefined
}
const limit = Number(flag('--limit') ?? Number.POSITIVE_INFINITY)
const onlyRecipe = flag('--recipe')

// ---- Credentials -------------------------------------------------------------

if (getApps().length === 0) initializeApp({ projectId: PROJECT_ID })
const db = getFirestore()

// The key the function reads, read the same way: from the environment when the
// developer put it there, from Secret Manager otherwise — through the same
// application-default credentials Firestore is reached with.
const geminiApiKey = async (): Promise<string> => {
  if (process.env.NITRO_GOOGLE_API_KEY) return process.env.NITRO_GOOGLE_API_KEY
  const auth = new GoogleAuth({ scopes: ['https://www.googleapis.com/auth/cloud-platform'] })
  const client = await auth.getClient()
  const response = await client.request<{ payload: { data: string } }>({
    url: `https://secretmanager.googleapis.com/v1/projects/${PROJECT_ID}/secrets/google-api-key/versions/latest:access`,
  })
  return Buffer.from(response.data.payload.data, 'base64').toString('utf8')
}

// ---- What the model reads ----------------------------------------------------

type Ingredient = { name: string; quantity: string }
type ThermomixSettings = { time?: string; temperature?: string; speed?: string; reverse?: boolean }
type StoredStep = string | { text: string; settings: ThermomixSettings }

// A step's Thermomix settings, spelled out for the prompt the way the proposal
// prompt spells them. A dish step is a bare string and sets nothing.
const formatStep = (step: StoredStep): string => {
  if (typeof step === 'string') return step
  const parts = [
    step.settings.time && `time ${step.settings.time}`,
    step.settings.temperature && `temperature ${step.settings.temperature}`,
    step.settings.speed && `speed ${step.settings.speed}`,
    step.settings.reverse && 'reverse rotation',
  ].filter(Boolean)
  return parts.length ? `${step.text} [Thermomix: ${parts.join(', ')}]` : step.text
}

const prompt = (title: string, ingredients: Ingredient[], steps: StoredStep[]): string => {
  const ingredientLines =
    ingredients.map(({ name, quantity }) => `- ${name} : ${quantity}`).join('\n') || '—'
  const stepLines = steps.map((s, i) => `${i + 1}. ${formatStep(s)}`).join('\n') || '—'

  return `You are the assistant of a culinary experimentation notebook. This recipe was written down before the notebook had a mise en place section. Write that section for it, and nothing else.

MANDATORY: write every line in French. The reader is a French speaker; never answer in English.

The mise en place is EVERYTHING readied before the first step, as a professional kitchen does it — one short line per preparation, imperative mood. Read every step and pull out what it assumes ready: what is taken out ahead (butter softening, meat at room temperature), weighed or measured, washed, peeled, cut — with the cut ("Émincer 2 oignons", "Couper le bœuf en cubes de 4 cm") —, soaked, toasted, preheated (oven with its temperature, pan, water), lined or greased. Derive it from the ingredients and the steps below; invent no ingredient and no quantity the recipe does not state. Empty array only when the recipe truly readies nothing.

Recipe: ${title}

Ingredients:
${ingredientLines}

Steps:
${stepLines}

Reminder: all lines you produce must be written in French.`
}

const responseSchema = {
  type: 'object',
  properties: { miseEnPlace: miseEnPlaceSchemaProperty },
  required: ['miseEnPlace'],
  propertyOrdering: ['miseEnPlace'],
}

// Ask, then read the answer the way the AI parse layer reads a list: strings only,
// trimmed, clamped to a step's length, blanks dropped, count capped.
const askMiseEnPlace = async (apiKey: string, text: string): Promise<string[]> => {
  const response = await fetch(`${GEMINI_API_URL}?key=${apiKey}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      contents: [{ parts: [{ text }] }],
      generationConfig: { responseMimeType: 'application/json', responseSchema },
    }),
    signal: AbortSignal.timeout(45_000),
  })
  if (!response.ok) throw new Error(`Gemini answered ${response.status}: ${await response.text()}`)
  const body = (await response.json()) as {
    candidates?: { content: { parts: { text?: string }[] } }[]
  }
  const answer = body.candidates?.[0]?.content?.parts?.find(({ text }) => text)?.text
  if (!answer) throw new Error('Gemini did not return a structured mise en place')
  const parsed = JSON.parse(answer) as { miseEnPlace?: unknown }
  const lines = Array.isArray(parsed.miseEnPlace) ? parsed.miseEnPlace : []
  return lines
    .filter((line): line is string => typeof line === 'string')
    .map((line) => line.trim().slice(0, RECIPE_MAX.stepText))
    .filter((line) => line.length > 0)
    .slice(0, MAX_LINES)
}

// ---- The versions to write ---------------------------------------------------

type Candidate = {
  ref: FirebaseFirestore.DocumentReference
  data: DocumentData
  title: string
  label: string
}

// Filtered in memory rather than queried: Firestore cannot ask for an empty array
// inside a map, and the notebook is one cook's — reading it whole is one query.
const candidates = async (): Promise<Candidate[]> => {
  const [recipes, versions] = await Promise.all([
    db.collection('recipes').get(),
    onlyRecipe
      ? db.collection('recipe-versions').where('recipeId', '==', onlyRecipe).get()
      : db.collection('recipe-versions').get(),
  ])
  const titles = new Map(recipes.docs.map((doc) => [doc.id, doc.data().title as string]))

  return versions.docs
    .filter((doc) => {
      const { content } = doc.data()
      if (content.kind !== 'dish' && content.kind !== 'thermomix') return false
      if ((content.miseEnPlace ?? []).length > 0) return false
      return content.steps.length > 0
    })
    .map((doc) => {
      const data = doc.data()
      const title = titles.get(data.recipeId) ?? data.recipeId
      return { ref: doc.ref, data, title, label: `${title} v${data.number}` }
    })
    .sort((a, b) => a.label.localeCompare(b.label))
}

// ---- Run ---------------------------------------------------------------------

const pause = () => new Promise((resolve) => setTimeout(resolve, PAUSE_MS))

const run = async () => {
  const todo = await candidates()
  console.log(
    `${todo.length} cooked version(s) without a mise en place${onlyRecipe ? ` in recipe ${onlyRecipe}` : ''}`,
  )
  if (dryRun) {
    for (const { label } of todo) console.log(`  would write  ${label}`)
    return
  }
  if (todo.length === 0) return

  const apiKey = await geminiApiKey()
  let written = 0
  let failed = 0
  for (const { ref, data, title, label } of todo) {
    if (written >= limit) {
      console.log(`stopping at --limit ${limit}`)
      break
    }
    const { content } = data
    try {
      const miseEnPlace = await askMiseEnPlace(
        apiKey,
        prompt(title, content.ingredients, content.steps),
      )
      await ref.set({ ...data, content: { ...content, miseEnPlace } })
      written++
      console.log(`  written  ${label}  (${miseEnPlace.length} line(s))`)
      for (const line of miseEnPlace) console.log(`             - ${line}`)
    } catch (error) {
      failed++
      console.error(`  FAILED   ${label}: ${error instanceof Error ? error.message : error}`)
    }
    await pause()
  }
  console.log(`\n${written} written, ${failed} failed, ${todo.length - written - failed} left`)
  if (failed > 0) process.exitCode = 1
}

await run()
