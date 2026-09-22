import { monthOf } from '~/domain/quota/business-rules'
import * as repository from '~/domain/quota/infrastructure/repository'
import type { Quota } from '~/domain/quota/types'
import type { UserId } from '~/domain/shared/types'

export namespace QuotaQuery {
  // This month's consumption for that cook — zeros until the first AI call.
  export const current = async (userId: UserId): Promise<Quota> =>
    repository.findBy(userId, monthOf(new Date()))
}
