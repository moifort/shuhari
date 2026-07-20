import { consumed, monthOf } from '~/domain/quota/business-rules'
import * as repository from '~/domain/quota/infrastructure/repository'
import type { AiAction, Quota } from '~/domain/quota/types'
import type { UserId } from '~/domain/shared/types'

export namespace QuotaCommand {
  // Write down one AI call that actually happened. Called AFTER the AI answered,
  // never before: a Gemini failure must not cost the cook a quota, and a refused
  // request never reaches this point. One document, so a plain set — no batch.
  export const record = async (userId: UserId, action: AiAction): Promise<Quota> => {
    const quota = await repository.findBy(userId, monthOf(new Date()))
    return repository.save(consumed(quota, action))
  }

  // Everything this domain holds on one cook, erased. Called only when the account
  // itself goes: there is no other reason to forget what the AI already cost.
  export const forget = (userId: UserId): Promise<void> => repository.removeAllByUser(userId)
}
