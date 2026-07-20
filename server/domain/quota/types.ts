import type { Brand } from 'ts-brand'
import type { Count, UserId } from '~/domain/shared/types'

// What a cook is entitled to. `free` is the default for everyone; `premium` is
// the paid subscription — unlimited AI, plus the URL import.
export const PLAN_VALUES = ['free', 'premium'] as const
export type Plan = (typeof PLAN_VALUES)[number]

// The two AI meters. `import` is one recipe analysis (photos, text or URL);
// `iteration` is one call that reworks an existing version — a proposal, an
// improvement or a tips merge.
export const AI_ACTION_VALUES = ['import', 'iteration'] as const
export type AiAction = (typeof AI_ACTION_VALUES)[number]

// The calendar month a quota counts for, `"2026-07"`. The window IS the month:
// the counters never reset, the next month simply gets its own document.
export type QuotaMonth = Brand<string, 'QuotaMonth'>

// One cook's AI consumption for one month. Absent storage means a fresh month,
// which reads back as both counters at zero (see the repository).
export type Quota = {
  userId: UserId
  month: QuotaMonth
  imports: Count
  iterations: Count
}
