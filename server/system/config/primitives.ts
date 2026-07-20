import { Environment } from '@apple/app-store-server-library'
import { make } from 'ts-brand'
import { z } from 'zod'
import { UserId } from '~/domain/shared/primitives'
import type {
  AdminToken as AdminTokenType,
  ApiToken as ApiTokenType,
  AppleAppId as AppleAppIdType,
  GoogleApiKey as GoogleApiKeyType,
} from '~/system/config/types'

export const ApiToken = (value: unknown) => {
  const v = z.string().min(1).parse(value)
  return make<ApiTokenType>()(v)
}

export const AdminToken = (value: unknown) => {
  const v = z.string().min(1).parse(value)
  return make<AdminTokenType>()(v)
}

export const GoogleApiKey = (value: unknown) => {
  const v = z.string().min(1).parse(value)
  return make<GoogleApiKeyType>()(v)
}

// The cooks on the Premium plan, given as one comma-separated list of Firebase
// uids. Temporary source of the entitlement, until in-app purchase ships — see
// `QuotaQuery.planOf`. Blank (the default) means nobody is Premium.
export const PremiumUserIds = (value: unknown) => {
  const v = z.string().parse(value ?? '')
  return v
    .split(',')
    .map((id) => id.trim())
    .filter((id) => id.length > 0)
    .map(UserId)
}

// The app's numeric App Store identifier, required to verify a Production
// signature (Apple omits it in the sandbox). Blank until the app has an id.
export const AppleAppId = (value: unknown) => {
  const v = z.coerce.number().int().positive().parse(value)
  return make<AppleAppIdType>()(v)
}

// Pins signature verification to one App Store environment. Blank (production
// default) means both Production and Sandbox are tried, which is what a shipped
// app needs; `Xcode` is for the local StoreKit configuration file.
export const AppleEnvironment = (value: unknown) => z.enum(Environment).parse(value) as Environment
