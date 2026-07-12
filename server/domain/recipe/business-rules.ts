import { VersionNumber as toVersionNumber } from '~/domain/recipe/primitives'
import type { Param, ParamKey, StepText, TmxSettings, VersionNumber } from '~/domain/recipe/types'
import type { Note } from '~/domain/trial/types'

// A trial promotes its version to "current" (the reproducible reference) when the
// note reaches this threshold. Mirrors the maquette's saveEssai logic.
export const PROMOTION_NOTE = 8

// A version becomes the new reference only when a HIGH-scoring trial ran against
// the exact version that was awaiting testing.
export const readyToPromote = (
  note: Note,
  testedVersion: VersionNumber,
  toTest: VersionNumber | null,
): boolean => toTest !== null && testedVersion === toTest && note >= PROMOTION_NOTE

export const nextVersionNumber = (versionCount: VersionNumber): VersionNumber =>
  toVersionNumber(versionCount + 1)

// Thermomix settings are only usable when they mirror the steps one-to-one and
// at least one step actually carries a setting; anything else is dropped so the
// stored version never holds a misaligned or empty parallel array. Entries
// without any actual setting (reverse alone carries none when false) are
// normalized to null.
export const alignedTmxSteps = (
  steps: StepText[],
  tmxSteps: (TmxSettings | null)[] | undefined,
): (TmxSettings | null)[] | undefined => {
  if (!tmxSteps || tmxSteps.length !== steps.length) return undefined
  const normalized = tmxSteps.map((s) => (s && !emptySettings(s) ? s : null))
  return normalized.some((s) => s !== null) ? normalized : undefined
}

const emptySettings = (s: TmxSettings): boolean =>
  s.time === undefined && s.temperature === undefined && s.speed === undefined && !s.reverse

// Ordered merge of a proposal's changes onto a version's target params: an
// existing key is replaced in place (order preserved), a new key is appended.
export const applyProposalToParams = (
  params: Param[],
  changes: { key: ParamKey; value: Param['value'] }[],
): Param[] => {
  const result = params.map((p) => ({ ...p }))
  for (const change of changes) {
    const existing = result.find((p) => p.key === change.key)
    if (existing) existing.value = change.value
    else result.push({ key: change.key, value: change.value })
  }
  return result
}
