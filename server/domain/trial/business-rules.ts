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
