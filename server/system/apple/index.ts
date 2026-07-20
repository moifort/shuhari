import {
  Environment,
  type JWSTransactionDecodedPayload,
  SignedDataVerifier,
} from '@apple/app-store-server-library'
import { appleRootCertificates } from '~/system/apple/root-certificates'
import type { AppleNotification, AppleTransaction } from '~/system/apple/types'
import { BUNDLE_ID } from '~/system/apple/types'
import { config } from '~/system/config'

// Which App Store a signature may come from. A shipped app receives both at once
// — TestFlight and review sign in Sandbox, the App Store in Production — so both
// are tried unless a single environment is pinned (`NITRO_APPLE_ENVIRONMENT`,
// set to `Xcode` for the local StoreKit configuration file, whose payloads are
// signed by a throwaway local certificate and cannot chain to Apple's roots).
const environments = (): Environment[] => {
  const pinned = config().appleEnvironment
  return pinned ? [pinned] : [Environment.PRODUCTION, Environment.SANDBOX]
}

// One verifier per environment, rebuilt per call: they are cheap, and a cached
// one would outlive a configuration change in a long-running instance.
const verifiers = () =>
  environments().map(
    (environment) =>
      new SignedDataVerifier(
        appleRootCertificates(),
        // Online revocation checks call out to Apple on every verification. Off:
        // a revoked receipt reaches us through the notification webhook, which is
        // the channel built for it.
        false,
        environment,
        BUNDLE_ID,
        config().appleAppId,
      ),
  )

// Apple's library throws on an unverifiable payload; the domain speaks in
// sentinels, so the boundary converts. Every environment is tried before giving
// up — a payload signed for Sandbox simply fails the Production verifier.
const verifyAcrossEnvironments = async <T>(
  verify: (verifier: SignedDataVerifier) => Promise<T>,
): Promise<T | 'invalid-signature'> => {
  for (const verifier of verifiers()) {
    try {
      return await verify(verifier)
    } catch {
      // Try the next environment.
    }
  }
  return 'invalid-signature'
}

// Apple's payload → the shape the domain acts on. A transaction with no product
// or no original id is not one we can attach to a cook.
const toTransaction = (payload: JWSTransactionDecodedPayload): AppleTransaction | undefined =>
  payload.productId && payload.originalTransactionId
    ? {
        productId: payload.productId,
        originalTransactionId: payload.originalTransactionId,
        ...(payload.appAccountToken ? { appAccountToken: payload.appAccountToken } : {}),
        ...(payload.expiresDate ? { expiresAt: new Date(payload.expiresDate) } : {}),
        ...(payload.revocationDate ? { revokedAt: new Date(payload.revocationDate) } : {}),
      }
    : undefined

export namespace Apple {
  // Check a signed transaction handed over by the app and decode what it grants.
  // This is the only thing standing between a client claim and Premium: the
  // signature proves Apple sold it, and nothing here trusts the caller.
  export const verifyTransaction = async (
    signedTransaction: string,
  ): Promise<AppleTransaction | 'invalid-signature'> => {
    const payload = await verifyAcrossEnvironments((verifier) =>
      verifier.verifyAndDecodeTransaction(signedTransaction),
    )
    if (payload === 'invalid-signature') return 'invalid-signature'
    return toTransaction(payload) ?? 'invalid-signature'
  }

  // Check a signed App Store Server Notification and decode the transaction it
  // carries. Same signature check: the webhook is unauthenticated by design, its
  // only proof of origin is this.
  export const verifyNotification = async (
    signedPayload: string,
  ): Promise<AppleNotification | 'invalid-signature'> => {
    const payload = await verifyAcrossEnvironments((verifier) =>
      verifier.verifyAndDecodeNotification(signedPayload),
    )
    if (payload === 'invalid-signature') return 'invalid-signature'

    const signedTransaction = payload.data?.signedTransactionInfo
    const transaction = signedTransaction
      ? await verifyTransaction(signedTransaction)
      : 'invalid-signature'
    return {
      type: payload.notificationType ?? 'UNKNOWN',
      ...(payload.subtype ? { subtype: payload.subtype } : {}),
      ...(transaction === 'invalid-signature' ? {} : { transaction }),
    }
  }
}
