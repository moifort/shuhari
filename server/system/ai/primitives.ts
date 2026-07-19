import { make } from 'ts-brand'
import { z } from 'zod'
import { RECIPE_MAX } from '~/domain/recipe/limits'
import { DISH_CATEGORY_VALUES, RECIPE_TYPE_VALUES } from '~/domain/recipe/types'
import type {
  ImportAnalysis,
  ImportHash as ImportHashType,
  ImportTmxSettings,
  Proposal,
} from '~/system/ai/types'

export const ImportHash = (value: unknown) => {
  const v = z
    .string()
    .regex(/^[0-9a-f]{64}$/)
    .parse(value)
  return make<ImportHashType>()(v)
}

// Gemini can't be trusted to respect our field sizes, so every string it returns
// is trimmed and truncated to the matching domain limit BEFORE it can reach a
// branded primitive (which would otherwise throw a 400/500 on overflow). We
// truncate rather than reject — the import preview is editable, so a clipped
// value is fixable, a hard error is not.
const clamped = (max: number) => z.string().transform((s) => s.trim().slice(0, max))

// Required string field → clamped, tolerating absent/null by yielding '' (Gemini
// sometimes nulls a required field even when told not to). A blank result is then
// dropped by the array filters instead of throwing and failing the whole parse.
const clampedField = (max: number) =>
  z
    .string()
    .nullish()
    .transform((v) => (v ?? '').trim().slice(0, max))

// Optional/nullable string → clamped, or null when absent/blank.
const optionalClamped = (max: number) =>
  z
    .string()
    .nullish()
    .transform((v) => {
      const t = (v ?? '').trim().slice(0, max)
      return t.length ? t : null
    })

const nullToNull = <T>(schema: z.ZodType<T>) => schema.nullish().transform((v) => v ?? null)

// Generous caps for fields that reach the domain unvalidated (no branded scalar):
// they can't 400, but an unbounded value would bloat the Firestore document.
const SOURCE_LABEL_MAX = 200
const RATIONALE_MAX = 2000

// Cap array element counts so a runaway response can't produce thousands of rows.
// Generous — real recipes/proposals stay well under this.
const MAX_ITEMS = 100

const ingredientSchema = z.object({
  name: clampedField(RECIPE_MAX.ingredientName),
  quantity: clampedField(RECIPE_MAX.ingredientQuantity),
})

// A step comes back as an object carrying the text plus optional Thermomix
// settings; a bare string (schema-less fallback) is tolerated as a plain step.
const stepSchema = z.union([
  clamped(RECIPE_MAX.stepText).transform((text) => ({ text, tmx: null })),
  z
    .object({
      text: clampedField(RECIPE_MAX.stepText),
      tmxTime: optionalClamped(RECIPE_MAX.tmx),
      tmxTemperature: optionalClamped(RECIPE_MAX.tmx),
      tmxSpeed: optionalClamped(RECIPE_MAX.tmx),
      tmxReverse: nullToNull(z.boolean()),
    })
    .transform(({ text, tmxTime, tmxTemperature, tmxSpeed, tmxReverse }) => ({
      text,
      // tmxReverse: false carries no information — Gemini sometimes emits it
      // instead of null on plain steps, and it must not turn them into
      // "Thermomix" steps.
      tmx:
        tmxTime === null && tmxTemperature === null && tmxSpeed === null && !tmxReverse
          ? null
          : { time: tmxTime, temperature: tmxTemperature, speed: tmxSpeed, reverse: tmxReverse },
    })),
])

// Drop blank ingredients and cap the count. Shared by import and proposal.
const foldIngredients = (raw: { name: string; quantity: string }[]) =>
  raw.filter((i) => i.name && i.quantity).slice(0, MAX_ITEMS)

// Drop blank steps, cap the count, and split into aligned steps/tmxSteps arrays.
// tmxSteps collapses to null when no surviving step carries a setting. Shared by
// import and proposal.
const foldSteps = (
  raw: { text: string; tmx: ImportTmxSettings | null }[],
): { steps: string[]; tmxSteps: (ImportTmxSettings | null)[] | null } => {
  const kept = raw.filter((s) => s.text.length > 0).slice(0, MAX_ITEMS)
  const tmxSteps = kept.map((s) => s.tmx)
  return {
    steps: kept.map((s) => s.text),
    tmxSteps: tmxSteps.some((s) => s !== null) ? tmxSteps : null,
  }
}

// Gemini marks absent fields as explicit null (the prompt instructs it to), so
// every optional field accepts null. All strings are clamped; array items whose
// required fields came back blank are dropped rather than failing the parse.
export const ImportAnalysisSchema = z
  .object({
    type: z.enum(RECIPE_TYPE_VALUES),
    // Best-effort detection: an unknown/missing category defaults to 'main'.
    category: z.enum(DISH_CATEGORY_VALUES).catch('main'),
    title: clampedField(RECIPE_MAX.title),
    sourceLabel: optionalClamped(SOURCE_LABEL_MAX),
    ingredients: z.array(ingredientSchema).default([]),
    steps: z.array(stepSchema).default([]),
  })
  .transform((raw): ImportAnalysis => {
    const { steps, tmxSteps } = foldSteps(raw.steps)
    return {
      type: raw.type,
      category: raw.category,
      // Title is required downstream; never let a blank one through.
      title: raw.title || 'Recette importée',
      sourceLabel: raw.sourceLabel,
      ingredients: foldIngredients(raw.ingredients),
      steps,
      tmxSteps,
    }
  })

export const ProposalSchema = z
  .object({
    changeSummary: clampedField(RECIPE_MAX.changeSummary),
    rationale: clampedField(RATIONALE_MAX),
    ingredients: z.array(ingredientSchema).default([]),
    steps: z.array(stepSchema).default([]),
  })
  .transform((raw): Proposal => {
    const { steps, tmxSteps } = foldSteps(raw.steps)
    return {
      changeSummary: raw.changeSummary,
      rationale: raw.rationale,
      ingredients: foldIngredients(raw.ingredients),
      steps,
      tmxSteps,
    }
  })

// The model's explicit signal that the source holds no recipe. Checked before
// the full schema so a `recipeFound: false` reply with everything else blank
// never trips the stricter parse.
const RecipeFoundSchema = z.object({ recipeFound: z.boolean().catch(true) })

export const parseImportResponse = (text: string): ImportAnalysis | 'no-recipe-found' => {
  const raw = JSON.parse(text)
  if (!RecipeFoundSchema.parse(raw).recipeFound) return 'no-recipe-found'
  const analysis = ImportAnalysisSchema.parse(raw)
  // An allegedly-found recipe with neither ingredients nor steps is equally no
  // recipe — a real one always yields at least one of the two.
  return analysis.ingredients.length === 0 && analysis.steps.length === 0
    ? 'no-recipe-found'
    : analysis
}

export const parseProposalResponse = (text: string): Proposal =>
  ProposalSchema.parse(JSON.parse(text))
