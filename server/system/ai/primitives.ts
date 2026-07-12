import { make } from 'ts-brand'
import { z } from 'zod'
import { RECIPE_TYPE_VALUES } from '~/domain/recipe/types'
import type { ImportAnalysis, ImportHash as ImportHashType, ProposalDraft } from '~/system/ai/types'

export const ImportHash = (value: unknown) => {
  const v = z
    .string()
    .regex(/^[0-9a-f]{64}$/)
    .parse(value)
  return make<ImportHashType>()(v)
}

const nullToNull = <T>(schema: z.ZodType<T>) => schema.nullish().transform((v) => v ?? null)

const paramSchema = z.object({ key: z.string().min(1), value: z.string().min(1) })

// A step comes back as an object carrying the text plus optional Thermomix
// settings; a bare string (schema-less fallback) is tolerated as a plain step.
const stepSchema = z.union([
  z
    .string()
    .min(1)
    .transform((text) => ({ text, tmx: null })),
  z
    .object({
      text: z.string().min(1),
      tmxTime: nullToNull(z.string().min(1)),
      tmxTemperature: nullToNull(z.string().min(1)),
      tmxSpeed: nullToNull(z.string().min(1)),
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
// every optional field accepts null.
export const ImportAnalysisSchema = z
  .object({
    type: z.enum(RECIPE_TYPE_VALUES),
    title: z.string().min(1),
    subtitle: nullToNull(z.string()),
    sourceLabel: nullToNull(z.string()),
    params: z.array(paramSchema).default([]),
    steps: z.array(stepSchema).default([]),
  })
  .transform((raw): ImportAnalysis => {
    const tmxSteps = raw.steps.map((s) => s.tmx)
    return {
      type: raw.type,
      title: raw.title,
      subtitle: raw.subtitle,
      sourceLabel: raw.sourceLabel,
      params: raw.params,
      steps: raw.steps.map((s) => s.text),
      tmxSteps: tmxSteps.some((s) => s !== null) ? tmxSteps : null,
    }
  })

export const ProposalDraftSchema = z
  .object({
    vars: z
      .array(
        z.object({ key: z.string().min(1), from: nullToNull(z.string()), to: z.string().min(1) }),
      )
      .default([]),
    rationale: z.string().default(''),
    queued: z.array(z.string()).default([]),
    recommendation: z.enum(['iteration', 'variation']).default('iteration'),
    variation: nullToNull(z.object({ title: z.string().min(1), description: z.string() })),
  })
  .transform(
    (raw): ProposalDraft => ({
      vars: raw.vars,
      rationale: raw.rationale,
      queued: raw.queued,
      recommendation: raw.recommendation,
      variation: raw.variation,
    }),
  )

export const parseImportResponse = (text: string): ImportAnalysis =>
  ImportAnalysisSchema.parse(JSON.parse(text))

export const parseProposalResponse = (text: string): ProposalDraft =>
  ProposalDraftSchema.parse(JSON.parse(text))
