import { freshQuota } from '~/domain/quota/business-rules'
import type { Quota, QuotaMonth } from '~/domain/quota/types'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import { evictFromRequestCache, memoizedPerRequest } from '~/system/request-cache'
import { genericDataConverter } from '~/utils/firestore'

const quotas = () => db().collection('ai-quotas').withConverter(genericDataConverter<Quota>())

// One document per cook and per month, keyed deterministically: the month's quota
// is read by key, never by query, and last month's document is simply never read
// again — no purge, no scheduled job.
const quotaDocId = (userId: UserId, month: QuotaMonth) => `${userId}_${month}`

// Memoized for the request: a mutation checks the quota before calling the AI and
// records it after, and both must share the same single read.
export const findBy = (userId: UserId, month: QuotaMonth): Promise<Quota> =>
  memoizedPerRequest(`quota:${userId}:${month}`, async () => {
    const doc = await quotas().doc(quotaDocId(userId, month)).get()
    // An absent document is a month nobody has spent anything in — the storage
    // boundary defaults it rather than making every caller handle absence.
    return doc.data() ?? freshQuota(userId, month)
  })

export const save = async (quota: Quota): Promise<Quota> => {
  await quotas().doc(quotaDocId(quota.userId, quota.month)).set(quota)
  // Drop the memoized pre-write value so anything reading the quota later in the
  // same request (the `quota` query alongside a mutation) sees what was just spent.
  evictFromRequestCache(`quota:${quota.userId}:${quota.month}`)
  return quota
}
