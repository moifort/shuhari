import type { ProposalVar } from '~/domain/proposal/types'
import type { RecipeType } from '~/domain/recipe/types'

// The scientific constraint at the heart of the product: coffee and cocktails
// change EXACTLY ONE variable per iteration (so cause and effect stay legible);
// dishes and Thermomix recipes may change several at once.
export type VariableBudget = 1 | 'many'

export const variableBudget = (type: RecipeType): VariableBudget =>
  type === 'cafe' || type === 'cocktail' ? 1 : 'many'

export const respectsVariableBudget = (type: RecipeType, vars: ProposalVar[]): boolean => {
  const budget = variableBudget(type)
  if (budget === 'many') return vars.length >= 1
  return vars.length === 1
}

// Enforce the one-variable rule on a raw AI proposal: for coffee/cocktail keep
// only the first change and push the rest into `queued` as follow-up leads
// (the AI "orders them into successive iterations" — spec). A textual lead is
// derived for each overflowed variable so the app can surface the file d'attente.
export const overflowToQueue = (
  type: RecipeType,
  vars: ProposalVar[],
  existingQueue: string[] = [],
): { vars: ProposalVar[]; queued: string[] } => {
  if (variableBudget(type) === 'many' || vars.length <= 1) {
    return { vars, queued: existingQueue }
  }
  const [head, ...rest] = vars
  const overflowLeads = rest.map((v) => `${v.key} : ${v.from ?? '—'} → ${v.to}`)
  return { vars: [head], queued: [...existingQueue, ...overflowLeads] }
}
