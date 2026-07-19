import type { Brand } from 'ts-brand'
import type { DishCategory, RecipeType } from '~/domain/recipe/types'

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
  category: DishCategory
  title: string
  sourceLabel: string | null
  ingredients: { name: string; quantity: string }[]
  steps: string[]
  // Aligned with `steps` by index; null when no step carries a setting.
  tmxSteps: (ImportTmxSettings | null)[] | null
}

export type CachedImport = {
  importHash: ImportHash
  result: ImportAnalysis
  cachedAt: Date
}

// Context handed to the proposal model: the full current version and the attempts
// run against it, so the AI can propose the next version.
export type ProposalContext = {
  type: RecipeType
  category: DishCategory
  currentIngredients: { name: string; quantity: string }[]
  currentSteps: string[]
  // Aligned with `currentSteps` by index; null when a step carries no setting.
  currentTmxSteps: (ImportTmxSettings | null)[]
  attempts: {
    rating: number
    remarks: string
  }[]
}

// Raw next-version proposal produced by Gemini — a full ingredient/step list
// plus a short change summary. Plain strings, validated into branded types on accept.
export type Proposal = {
  changeSummary: string
  rationale: string
  ingredients: { name: string; quantity: string }[]
  steps: string[]
  // Aligned with `steps` by index; null when no step carries a setting.
  tmxSteps: (ImportTmxSettings | null)[] | null
}
