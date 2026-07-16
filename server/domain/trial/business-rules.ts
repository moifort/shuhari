import type { Param } from '~/domain/recipe/types'
import type { Note } from '~/domain/trial/types'

// Mean trial note, rounded to one decimal, or null when there are no trials.
export const averageNote = (notes: Note[]) => {
  if (notes.length === 0) return null
  const sum = notes.reduce((total, note) => total + note, 0)
  return Math.round((sum / notes.length) * 10) / 10
}

// The best trial note a recipe ever scored, or null when there are no trials.
// Returns an actual element so the `Note` brand is preserved.
export const highestNote = (notes: Note[]): Note | null =>
  notes.length === 0 ? null : notes.reduce((best, note) => (note > best ? note : best))

// Keep only the parameters the cook actually changed relative to the version's
// targets — that minimal delta is what a trial stores (`realParams`). A value is
// a deviation when the key is absent from the targets or its value differs.
export const realDeviations = (targetParams: Param[], enteredParams: Param[]) => {
  const targetByKey = new Map(targetParams.map((p) => [p.key, p.value]))
  return enteredParams.filter((p) => targetByKey.get(p.key) !== p.value)
}

// Reconstruct the exact parameters of a past trial: the version's targets with
// the trial's real deviations overlaid (order of the targets preserved, extra
// real-only keys appended). Powers "refaire exactement cet essai".
export const replayParams = (targetParams: Param[], realParams: Param[]) => {
  const realByKey = new Map(realParams.map((p) => [p.key, p.value]))
  const merged = targetParams.map((p) => ({ key: p.key, value: realByKey.get(p.key) ?? p.value }))
  const targetKeys = new Set(targetParams.map((p) => p.key))
  const extras = realParams.filter((p) => !targetKeys.has(p.key)).map((p) => ({ ...p }))
  return [...merged, ...extras]
}
