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

// Ordered merge of a proposal's changes onto a version's target params: an
// existing key is replaced in place (order preserved), a new key is appended.
export const applyProposalToParams = (
  params: Param[],
  changes: { key: ParamKey; value: Param['value'] }[],
) => {
  const changeByKey = new Map(changes.map((change) => [change.key, change.value]))
  const existingKeys = new Set(params.map((param) => param.key))
  const updated = params.map((param) => {
    const value = changeByKey.get(param.key)
    return value === undefined ? param : { key: param.key, value }
  })
  const added = [...changeByKey.entries()]
    .filter(([key]) => !existingKeys.has(key))
    .map(([key, value]) => ({ key, value }))
  return [...updated, ...added]
}
