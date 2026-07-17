import { VersionNumber as toVersionNumber } from '~/domain/recipe/primitives'
import type {
  StepText,
  TmxSettings,
  TmxSpeed,
  TmxTemperature,
  TmxTime,
  VersionNumber,
} from '~/domain/recipe/types'
import type { Note } from '~/domain/trial/types'

// A trial promotes its version to "current" (the reproducible reference) when the
// note reaches this threshold (on the 1..5 scale). Mirrors the maquette's saveEssai logic.
export const PROMOTION_NOTE = 4

// A version becomes the new reference only when a HIGH-scoring trial ran against
// the exact version that was awaiting testing.
export const readyToPromote = (
  note: Note,
  testedVersion: VersionNumber,
  toTest: VersionNumber | null,
) => toTest !== null && testedVersion === toTest && note >= PROMOTION_NOTE

export const nextVersionNumber = (versionCount: VersionNumber) => toVersionNumber(versionCount + 1)

// Thermomix settings are only usable when they mirror the steps one-to-one and
// at least one step actually carries a setting; anything else is dropped so the
// stored version never holds a misaligned or empty parallel array. Entries
// without any actual setting (reverse alone carries none when false) are
// normalized to null.
export const alignedTmxSteps = (steps: StepText[], tmxSteps: (TmxSettings | null)[]) => {
  if (tmxSteps.length !== steps.length) return []
  const normalized = tmxSteps.map((s) => (s && !emptySettings(s) ? s : null))
  return normalized.some((s) => s !== null) ? normalized : []
}

const emptySettings = (s: TmxSettings) =>
  s.time === undefined && s.temperature === undefined && s.speed === undefined && !s.reverse

// One step's Thermomix settings as they arrive from a GraphQL input or a branded
// AI draft: each field may be present, null or absent. A `null`/`undefined` entry
// stands for a plain (non-Thermomix) step.
export type LooseTmxSettings = {
  time?: TmxTime | null
  temperature?: TmxTemperature | null
  speed?: TmxSpeed | null
  reverse?: boolean | null
}

// Normalize loose per-step settings into clean TmxSettings, dropping absent/null
// keys. `reverse` is kept only when true — false carries no information (a step
// whose only "setting" is reverse:false is not a Thermomix step). The single home
// for this rule so the GraphQL and AI-draft paths can never diverge;
// `alignedTmxSteps` then decides whether the parallel array is kept at all.
export const toTmxSettings = (
  entries: (LooseTmxSettings | null | undefined)[],
): (TmxSettings | null)[] =>
  entries.map((entry) =>
    entry
      ? {
          ...(entry.time ? { time: entry.time } : {}),
          ...(entry.temperature ? { temperature: entry.temperature } : {}),
          ...(entry.speed ? { speed: entry.speed } : {}),
          ...(entry.reverse ? { reverse: entry.reverse } : {}),
        }
      : null,
  )
