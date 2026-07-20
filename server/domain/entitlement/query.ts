import { appAccountToken, planOf as planFrom } from '~/domain/entitlement/business-rules'
import * as repository from '~/domain/entitlement/infrastructure/repository'
import type { AppAccountToken, Entitlement } from '~/domain/entitlement/types'
import type { Plan, UserId } from '~/domain/shared/types'
import { config } from '~/system/config'

export namespace EntitlementQuery {
  // What the App Store sold this cook, if anything. Absent is the normal state:
  // most cooks never subscribe.
  export const of = async (userId: UserId): Promise<Entitlement | undefined> =>
    repository.findBy(userId)

  // Whose entitlement carries that account token. The way in for the App Store
  // notifications, which name a cook only through the token they carry.
  export const byToken = async (token: AppAccountToken): Promise<Entitlement | undefined> =>
    repository.findByAppAccountToken(token)

  // The single answer to "what is this cook entitled to". Every AI gate goes
  // through here.
  //
  // `NITRO_PREMIUM_USER_IDS` stays as a comp list — the accounts we grant Premium
  // outright (the maker's own, a reviewer's). It is an override, no longer the
  // source: a real entitlement is a verified App Store transaction, nothing else.
  export const planOf = async (userId: UserId): Promise<Plan> => {
    if (config().premiumUserIds.includes(userId)) return 'premium'
    return planFrom(await of(userId), new Date())
  }

  // The UUID the app must hand StoreKit when it starts a purchase, so the signed
  // transaction comes back naming its cook. Derived here and never on the client:
  // one implementation, no algorithm to keep in sync across two languages.
  export const tokenFor = (userId: UserId): AppAccountToken => appAccountToken(userId)
}
