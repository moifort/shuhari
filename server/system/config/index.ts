import { AdminToken, ApiToken, GoogleApiKey, PremiumUserIds } from '~/system/config/primitives'

export const config = () => {
  const runtimeConfig = useRuntimeConfig()
  return {
    apiToken: runtimeConfig.apiToken ? ApiToken(runtimeConfig.apiToken) : undefined,
    adminToken: runtimeConfig.adminToken ? AdminToken(runtimeConfig.adminToken) : undefined,
    googleApiKey: GoogleApiKey(runtimeConfig.googleApiKey),
    premiumUserIds: PremiumUserIds(runtimeConfig.premiumUserIds),
  }
}
