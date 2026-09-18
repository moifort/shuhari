import type { OvenProfile } from '~/domain/recipe/content/oven'
import type { Ingredient, StepText } from '~/domain/recipe/types'

// A cooked-dish recipe's content: an ordered ingredient list and plain-text steps
// (no per-step machine settings), plus the oven settings it bakes at. `kind` mirrors
// the recipe type.
export type DishContent = {
  kind: 'dish'
  ingredients: Ingredient[]
  // What is readied before the first step — the professional kitchen's mise en
  // place: what is taken out, weighed, cut, preheated. Read once, before cooking
  // starts, so nothing surprises the cook mid-method. Written by the AI on every
  // version it produces (an import, a proposal, a change): a version stored before
  // the section existed reads as `[]` and gains one the next time the cook asks the
  // AI for an iteration. Plain text like a dish step — the mise en place is done by
  // hand, on a Thermomix recipe too.
  miseEnPlace: StepText[]
  steps: StepText[]
  // Absent when the dish never goes in the oven — its absence IS the information,
  // never an empty profile.
  oven?: OvenProfile
}
