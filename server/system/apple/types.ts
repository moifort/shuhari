/** The App Store bundle the signatures must belong to — a code fact, like the AI
 *  model, not an operational setting. */
export const BUNDLE_ID = 'com.polyforms.shuhari.app'

/** A purchase, once Apple's signature has been checked and the payload decoded.
 *  Only the fields the subscription domain acts on; everything else in Apple's
 *  payload is dropped at this boundary. Absent dates mean "no such event": a
 *  subscription with no `expiresAt` is not a subscription, and `revokedAt` is set
 *  only on a refund or a family-sharing removal. */
export type AppleTransaction = {
  productId: string
  originalTransactionId: string
  /** The UUID we handed StoreKit at purchase time — how a payment is tied back
   *  to a cook. Absent on a purchase made before we started sending it. */
  appAccountToken?: string
  expiresAt?: Date
  revokedAt?: Date
}

/** What Apple tells us happened, from an App Store Server Notification. The
 *  notification type is kept raw: the domain re-derives the plan from the
 *  transaction's dates rather than trusting an event name. */
export type AppleNotification = {
  type: string
  subtype?: string
  transaction?: AppleTransaction
}
