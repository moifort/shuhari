import { AdminToken, ApiToken, GoogleApiKey } from '~/system/config/primitives'

export const config = () => {
  const runtimeConfig = useRuntimeConfig()
  return {
    apiToken: runtimeConfig.apiToken ? ApiToken(runtimeConfig.apiToken) : undefined,
    adminToken: runtimeConfig.adminToken ? AdminToken(runtimeConfig.adminToken) : undefined,
    googleApiKey: GoogleApiKey(runtimeConfig.googleApiKey),
  }
}
