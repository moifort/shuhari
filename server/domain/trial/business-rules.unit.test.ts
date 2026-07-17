import { describe, expect, test } from 'bun:test'
import { averageNote, highestNote } from '~/domain/trial/business-rules'
import type { Note } from '~/domain/trial/types'

describe('averageNote', () => {
  const note = (n: number) => n as Note
  test('returns null for no trials', () => {
    expect(averageNote([])).toBeNull()
  })
  test('averages and rounds to one decimal', () => {
    expect(averageNote([note(3), note(4), note(5)])).toBe(4)
    expect(averageNote([note(4), note(5)])).toBe(4.5)
    expect(averageNote([note(4), note(5), note(5)])).toBeCloseTo(4.7, 5)
  })
})

describe('highestNote', () => {
  const note = (n: number) => n as Note
  test('returns null for no trials', () => {
    expect(highestNote([])).toBeNull()
  })
  test('returns the best note', () => {
    expect(highestNote([note(2), note(5), note(3)])).toBe(note(5))
  })
  test('handles a single note', () => {
    expect(highestNote([note(4)])).toBe(note(4))
  })
})
