import { consumed, exhausted, monthOf, refunded } from '~/domain/quota/business-rules'
import * as repository from '~/domain/quota/infrastructure/repository'
import type { AiAction, Quota } from '~/domain/quota/types'
import type { Plan, UserId } from '~/domain/shared/types'

export namespace QuotaCommand {
  // Spend one AI call BEFORE the AI is asked, the limit checked against the counter
  // in the same transaction. Checking first and recording after the answer let two
  // calls landing together both pass the check on the same count and overrun the
  // limit. What was spent is returned so it can be given back (`refund`). The plan
  // comes from the caller: what a cook is entitled to is the `entitlement` domain's
  // business, never storage this domain reads.
  export const spend = async (
    userId: UserId,
    plan: Plan,
    action: AiAction,
  ): Promise<Quota | 'quota-exhausted'> =>
    repository.rewrite(userId, monthOf(new Date()), (quota) =>
      exhausted(plan, quota, action) ? ('quota-exhausted' as const) : consumed(quota, action),
    )

  // Give back a call spent on an answer that never came — a Gemini failure, a recipe
  // that no longer exists, a source with no recipe in it. Charged to the month it was
  // spent in, even when the refund lands on the 1st of the next.
  export const refund = async (spent: Quota, action: AiAction): Promise<Quota> =>
    repository.rewrite(spent.userId, spent.month, (quota) => refunded(quota, action))

  // Everything this domain holds on one cook, erased. Called only when the account
  // itself goes: there is no other reason to forget what the AI already cost.
  export const forget = (userId: UserId): Promise<void> => repository.removeAllByUser(userId)
}
