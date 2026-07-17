import type { ProposalVar } from '~/domain/proposal/types'
import type { RecipeType } from '~/domain/recipe/types'

// Dishes and Thermomix recipes may change several variables per iteration.
export type VariableBudget = 1 | 'many'

export const variableBudget = (_type: RecipeType): VariableBudget => 'many'

// A proposal must change at least one variable (the 'many' budget imposes no
// upper bound).
export const respectsVariableBudget = (_type: RecipeType, vars: ProposalVar[]) => vars.length >= 1

// With the current 'many' budget every proposed variable is kept and the queue
// is passed through untouched. The single-variable overflow path is gone; the
// function stays until the proposal engine is redesigned.
export const overflowToQueue = (
  _type: RecipeType,
  vars: ProposalVar[],
  existingQueue: string[] = [],
) => ({ vars, queued: existingQueue })
