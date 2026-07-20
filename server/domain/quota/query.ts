import { exhausted, monthOf } from '~/domain/quota/business-rules'
import * as repository from '~/domain/quota/infrastructure/repository'
import type { AiAction, Quota } from '~/domain/quota/types'
import type { Plan, UserId } from '~/domain/shared/types'

export namespace QuotaQuery {
  // This month's consumption for that cook — zeros until the first AI call.
  export const current = async (userId: UserId): Promise<Quota> =>
    repository.findBy(userId, monthOf(new Date()))

  // Whether that action must be refused this month. Asked before the AI is
  // called, so a refusal costs nothing. The plan comes from the caller: what a
  // cook is entitled to is the `subscription` domain's business, never storage
  // this domain reads.
  export const exhaustedFor = async (
    userId: UserId,
    plan: Plan,
    action: AiAction,
  ): Promise<boolean> => exhausted(plan, await current(userId), action)
}
