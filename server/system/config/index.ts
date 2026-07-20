import { AdminToken, ApiToken, GoogleApiKey, PremiumUserIds } from '~/system/config/primitives'

// Each field is validated when it is read, not when `config()` is called: a
// missing Gemini key must break the AI, not the quota that gates it.
export const config = () => {
  const runtimeConfig = useRuntimeConfig()
  return {
    get apiToken() {
      return runtimeConfig.apiToken ? ApiToken(runtimeConfig.apiToken) : undefined
    },
    get adminToken() {
      return runtimeConfig.adminToken ? AdminToken(runtimeConfig.adminToken) : undefined
    },
    get googleApiKey() {
      return GoogleApiKey(runtimeConfig.googleApiKey)
    },
    get premiumUserIds() {
      return PremiumUserIds(runtimeConfig.premiumUserIds)
    },
  }
}
