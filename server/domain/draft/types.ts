import type { Ingredient, StepText, TmxSettings, VersionNumber } from '~/domain/recipe/types'

// An ephemeral next-version draft, already validated into branded domain shapes —
// either freshly branded from the AI or the user's inline edits from iOS. Never
// persisted: it is generated, returned, and handed straight back on accept.
export type Draft = {
  versionNumber: VersionNumber
  changeSummary: string
  rationale: string
  ingredients: Ingredient[]
  steps: StepText[]
  tmxSteps: (TmxSettings | null)[]
}

// The client-supplied draft to accept: everything that becomes version n+1,
// minus the versionNumber (the recipe assigns n+1 itself).
export type AcceptedDraft = Omit<Draft, 'versionNumber'>
