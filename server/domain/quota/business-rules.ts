import { QuotaMonth as toQuotaMonth } from '~/domain/quota/primitives'
import type { AiAction, Quota, QuotaMonth } from '~/domain/quota/types'
import { Count } from '~/domain/shared/primitives'
import type { Count as CountType, Plan, UserId } from '~/domain/shared/types'

// What a free cook gets each calendar month. AI is the app's only variable cost,
// so these two numbers are the whole free tier: recipes themselves stay unlimited.
// Single source of truth — the GraphQL surface and the enforcement both read it here.
export const FREE_LIMITS: Record<AiAction, CountType> = {
  import: Count(3),
  iteration: Count(5),
}

// The month a moment belongs to, `"2026-07"`. UTC on purpose: the window must not
// move with the caller's timezone, and a cook near midnight on the 1st is a rounding
// question nobody will ever ask.
export const monthOf = (moment: Date): QuotaMonth =>
  toQuotaMonth(`${moment.getUTCFullYear()}-${String(moment.getUTCMonth() + 1).padStart(2, '0')}`)

// When the counters go back to zero: midnight UTC on the 1st of the next month.
// `Date.UTC` rolls December over to January on its own.
export const renewsOn = (month: QuotaMonth): Date => {
  const [year, index] = (month as string).split('-').map(Number)
  return new Date(Date.UTC(year as number, index as number, 1))
}

// A month nobody has spent anything in yet — what an absent document means.
export const freshQuota = (userId: UserId, month: QuotaMonth): Quota => ({
  userId,
  month,
  imports: Count(0),
  iterations: Count(0),
})

export const used = (quota: Quota, action: AiAction): CountType =>
  action === 'import' ? quota.imports : quota.iterations

// How many of that action the plan allows per month — absent means unlimited,
// which is what Premium buys (fair use is a matter for the AI bill, not a counter).
export const limitOf = (plan: Plan, action: AiAction): CountType | undefined =>
  plan === 'premium' ? undefined : FREE_LIMITS[action]

// What is left this month, absent when the plan is unlimited. Never negative: a
// limit lowered under an already-spent counter reads as zero, not as a debt.
export const remaining = (plan: Plan, quota: Quota, action: AiAction): CountType | undefined => {
  const limit = limitOf(plan, action)
  return limit === undefined ? undefined : Count(Math.max(0, limit - used(quota, action)))
}

export const exhausted = (plan: Plan, quota: Quota, action: AiAction): boolean => {
  const limit = limitOf(plan, action)
  return limit !== undefined && used(quota, action) >= limit
}

// Reading a recipe off a web page is the one AI call billed per request (Google
// Search grounding), so it is the feature the subscription pays for.
export const allowsUrlImport = (plan: Plan): boolean => plan === 'premium'

// The quota once the action has been spent.
export const consumed = (quota: Quota, action: AiAction): Quota =>
  action === 'import'
    ? { ...quota, imports: Count(quota.imports + 1) }
    : { ...quota, iterations: Count(quota.iterations + 1) }
