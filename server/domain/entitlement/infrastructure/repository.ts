import type { AppAccountToken, Entitlement } from '~/domain/entitlement/types'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import { evictFromRequestCache, memoizedPerRequest } from '~/system/request-cache'
import { genericDataConverter, withoutAbsentFields } from '~/utils/firestore'

const entitlements = () =>
  db().collection('entitlements').withConverter(genericDataConverter<Entitlement>())

const cacheKey = (userId: UserId) => `entitlement:${userId}`

// Keyed by cook: one entitlement each, a renewal overwriting it in place.
// Memoized because the plan is read on every AI call and again by the `quota`
// query — one read per request, not three.
export const findBy = (userId: UserId): Promise<Entitlement | undefined> =>
  memoizedPerRequest(cacheKey(userId), async () => {
    const doc = await entitlements().doc(userId).get()
    return doc.data()
  })

// The webhook's way in: Apple's notification names the cook only through the
// account token it carries, and that derivation is one-way. A single-field
// equality query, which Firestore indexes on its own.
export const findByAppAccountToken = async (
  token: AppAccountToken,
): Promise<Entitlement | undefined> => {
  const snap = await entitlements().where('appAccountToken', '==', token).limit(1).get()
  return snap.docs[0]?.data()
}

export const save = async (entitlement: Entitlement): Promise<Entitlement> => {
  // Full `set`, never a merge: an omitted key erases the stored field, which is
  // what an absent `revokedAt` means (a refund reversed is Premium restored).
  await entitlements().doc(entitlement.userId).set(withoutAbsentFields(entitlement))
  evictFromRequestCache(cacheKey(entitlement.userId))
  return entitlement
}
