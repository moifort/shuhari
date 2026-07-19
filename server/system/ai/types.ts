import type { Brand } from 'ts-brand'
import type { DishCategory, RecipeType } from '~/domain/recipe/types'

export type ImportHash = Brand<string, 'ImportHash'>

// The three ways a recipe can be imported. Exactly one is set per request.
export type ImportSource =
  | { kind: 'photos'; photos: string[] } // base64 JPEGs (no data-URL prefix)
  | { kind: 'url'; url: string }
  | { kind: 'text'; text: string }

// Thermomix settings for one step as extracted by Gemini. Plain strings — the
// domain layer validates them into branded types when the user confirms. Every
// field absent (`{}`) means the step carries no Thermomix setting.
export type ImportTmxSettings = {
  time?: string
  temperature?: string
  speed?: string
  reverse?: boolean
}

// Raw structured recipe extracted by Gemini. Plain strings — the domain layer
// validates them into branded types when the user confirms the import.
export type ImportAnalysis = {
  type: RecipeType
  category: DishCategory
  title: string
  sourceLabel?: string
  ingredients: { name: string; quantity: string }[]
  steps: string[]
  // Aligned with `steps` by index; `[]` when no step carries a setting.
  tmxSteps: ImportTmxSettings[]
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
  // Aligned with `currentSteps` by index; an entry with no field is a plain step.
  currentTmxSteps: ImportTmxSettings[]
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
  // Aligned with `steps` by index; `[]` when no step carries a setting.
  tmxSteps: ImportTmxSettings[]
}
