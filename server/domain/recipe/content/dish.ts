import type { Ingredient, StepText } from '~/domain/recipe/types'

// A cooked-dish recipe's content: an ordered ingredient list and plain-text steps
// (no per-step machine settings). `kind` mirrors the recipe type.
export type DishContent = { kind: 'dish'; ingredients: Ingredient[]; steps: StepText[] }
