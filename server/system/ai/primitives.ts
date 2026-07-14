import { make } from 'ts-brand'
import { z } from 'zod'
import { RECIPE_MAX } from '~/domain/recipe/limits'
import { RECIPE_TYPE_VALUES } from '~/domain/recipe/types'
import type { ImportAnalysis, ImportHash as ImportHashType, ProposalDraft } from '~/system/ai/types'

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
const DESCRIPTION_MAX = 2000
const QUEUED_ITEM_MAX = 200

// Cap array element counts so a runaway response can't produce thousands of rows.
// Generous — real recipes/proposals stay well under this.
const MAX_ITEMS = 100

const paramSchema = z.object({
  key: clampedField(RECIPE_MAX.paramKey),
  value: clampedField(RECIPE_MAX.paramValue),
})

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

// Gemini marks absent fields as explicit null (the prompt instructs it to), so
// every optional field accepts null. All strings are clamped; array items whose
// required fields came back blank are dropped rather than failing the parse.
export const ImportAnalysisSchema = z
  .object({
    type: z.enum(RECIPE_TYPE_VALUES),
    title: clampedField(RECIPE_MAX.title),
    subtitle: optionalClamped(RECIPE_MAX.subtitle),
    sourceLabel: optionalClamped(SOURCE_LABEL_MAX),
    params: z.array(paramSchema).default([]),
    ingredients: z.array(ingredientSchema).default([]),
    steps: z.array(stepSchema).default([]),
  })
  .transform((raw): ImportAnalysis => {
    const steps = raw.steps.filter((s) => s.text.length > 0).slice(0, MAX_ITEMS)
    const tmxSteps = steps.map((s) => s.tmx)
    return {
      type: raw.type,
      // Title is required downstream; never let a blank one through.
      title: raw.title || 'Recette importée',
      subtitle: raw.subtitle,
      sourceLabel: raw.sourceLabel,
      params: raw.params.filter((p) => p.key && p.value).slice(0, MAX_ITEMS),
      ingredients: raw.ingredients.filter((i) => i.name && i.quantity).slice(0, MAX_ITEMS),
      steps: steps.map((s) => s.text),
      tmxSteps: tmxSteps.some((s) => s !== null) ? tmxSteps : null,
    }
  })

const proposalVarSchema = z.object({
  key: clampedField(RECIPE_MAX.paramKey),
  from: optionalClamped(RECIPE_MAX.paramValue),
  to: clampedField(RECIPE_MAX.paramValue),
})

export const ProposalDraftSchema = z
  .object({
    vars: z.array(proposalVarSchema).default([]),
    rationale: clampedField(RATIONALE_MAX),
    queued: z.array(clampedField(QUEUED_ITEM_MAX)).default([]),
    recommendation: z.enum(['iteration', 'variation']).default('iteration'),
    variation: nullToNull(
      z.object({
        title: clampedField(RECIPE_MAX.title),
        description: clampedField(DESCRIPTION_MAX),
      }),
    ),
  })
  .transform(
    (raw): ProposalDraft => ({
      vars: raw.vars.filter((v) => v.key && v.to).slice(0, MAX_ITEMS),
      rationale: raw.rationale,
      queued: raw.queued.filter((q) => q.length > 0).slice(0, MAX_ITEMS),
      recommendation: raw.recommendation,
      // A variation needs a title (it becomes a RecipeTitle) — drop it if blank.
      variation: raw.variation?.title ? raw.variation : null,
    }),
  )

export const parseImportResponse = (text: string): ImportAnalysis =>
  ImportAnalysisSchema.parse(JSON.parse(text))

export const parseProposalResponse = (text: string): ProposalDraft =>
  ProposalDraftSchema.parse(JSON.parse(text))
