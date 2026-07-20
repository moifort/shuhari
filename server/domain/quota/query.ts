import { exhausted, monthOf } from '~/domain/quota/business-rules'
import * as repository from '~/domain/quota/infrastructure/repository'
import type { AiAction, Plan, Quota } from '~/domain/quota/types'
import type { UserId } from '~/domain/shared/types'
import { config } from '~/system/config'

export namespace QuotaQuery {
  // This month's consumption for that cook — zeros until the first AI call.
  export const current = async (userId: UserId): Promise<Quota> =>
    repository.findBy(userId, monthOf(new Date()))

  // The StoreKit seam. Until in-app purchase ships there is no entitlement to
  // read, so Premium is granted by configuration (`NITRO_PREMIUM_USER_IDS`, uids
  // separated by commas). Replacing this one function with a lookup of the
  // verified App Store transaction is the whole of what the subscription adds.
  export const planOf = async (userId: UserId): Promise<Plan> =>
    config().premiumUserIds.includes(userId) ? 'premium' : 'free'

  // Whether that action must be refused this month. Asked before the AI is called,
  // so a refusal costs nothing.
  export const exhaustedFor = async (userId: UserId, action: AiAction): Promise<boolean> => {
    const [plan, quota] = await Promise.all([planOf(userId), current(userId)])
    return exhausted(plan, quota, action)
  }
}
