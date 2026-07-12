import type { Brand } from 'ts-brand'
import type { RecipeType } from '~/domain/recipe/types'

export type ImportHash = Brand<string, 'ImportHash'>

// The three ways a recipe can be imported. Exactly one is set per request.
export type ImportSource =
  | { kind: 'photos'; photos: string[] } // base64 JPEGs (no data-URL prefix)
  | { kind: 'url'; url: string }
  | { kind: 'text'; text: string }

// Thermomix settings for one step as extracted by Gemini. Plain strings — the
// domain layer validates them into branded types when the user confirms.
export type ImportTmxSettings = {
  time: string | null
  temperature: string | null
  speed: string | null
  reverse: boolean | null
}

// Raw structured recipe extracted by Gemini. Plain strings — the domain layer
// validates them into branded types when the user confirms the import.
export type ImportAnalysis = {
  type: RecipeType
  title: string
  subtitle: string | null
  sourceLabel: string | null
  params: { key: string; value: string }[]
  steps: string[]
  // Aligned with `steps` by index; null when no step carries a setting.
  tmxSteps: (ImportTmxSettings | null)[] | null
}

export type CachedImport = {
  importHash: ImportHash
  result: ImportAnalysis
  cachedAt: Date
}

// Context handed to the proposal model: the current version and the trials run
// against it, so the AI can reason about what to change next.
export type ProposalContext = {
  type: RecipeType
  currentParams: { key: string; value: string }[]
  currentSteps: string[]
  trials: {
    note: number
    remarks: string
    realParams: { key: string; value: string }[]
  }[]
  previousQueue: string[]
}

// Raw proposal drafted by Gemini, before the one-variable rule is enforced.
export type ProposalDraft = {
  vars: { key: string; from: string | null; to: string }[]
  rationale: string
  queued: string[]
  recommendation: 'iteration' | 'variation'
  variation: { title: string; description: string } | null
}
