import * as Sentry from '@sentry/node'
import { config } from '~/system/config'
import {
  claimRefresh,
  releaseRefresh,
  rememberTokens,
  storedTokens,
} from '~/system/electrolux/repository'

const REFRESH_URL = 'https://api.developer.electrolux.one/api/v1/token/refresh'
// How long an access token is trusted when Electrolux does not say. A minute of
// margin is taken off either way: a token that expires mid-request is a failed cook.
const DEFAULT_LIFETIME_MS = 60 * 60 * 1000
const MARGIN_MS = 60_000
// How long one instance may hold the right to spend the refresh token. Long enough
// for one round-trip to Electrolux and one Firestore write, short enough that an
// instance dying mid-refresh blocks the others for seconds, not for good.
const LEASE_MS = 15_000
// How an instance waits for another one's refresh: short looks at the shared
// document, for a lease's worth at most.
const WAIT_MS = 500
const WAIT_ATTEMPTS = LEASE_MS / WAIT_MS

// Mirrored on the instance so most calls cost no Firestore read at all.
let cached: { value: string; expiresAt: number } | undefined
// The access token the platform just answered 401 to. The shared document may
// still hold it as valid, and reusing it would make the retry pointless.
let rejectedAccess: string | undefined

// Forget the cached access token. The client calls this on a 401, so one expired
// token costs a single retry rather than every call until the instance recycles.
export const forgetAccessToken = () => {
  rejectedAccess = cached?.value
  cached = undefined
}

type Pair = { accessToken: string; refreshToken: string; expiresIn?: number }

// Spend one refresh token. `rejected` is Electrolux saying this one is spent or
// unknown — an outcome, not a fault.
const spend = async (apiKey: string, refreshToken: string): Promise<Pair | 'rejected'> => {
  const response = await fetch(REFRESH_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-api-key': apiKey },
    body: JSON.stringify({ refreshToken }),
  })
  if (response.status === 400 || response.status === 401) return 'rejected'
  if (!response.ok) throw new Error(`Electrolux refused the token refresh: ${response.status}`)
  return (await response.json()) as Pair
}

// The first candidate Electrolux accepts, or `rejected` when it refuses them all.
const spendFirst = async (apiKey: string, candidates: string[]): Promise<Pair | 'rejected'> => {
  const [candidate, ...rest] = candidates
  if (!candidate) return 'rejected'
  const pair = await spend(apiKey, candidate)
  return pair === 'rejected' ? spendFirst(apiKey, rest) : pair
}

const remember = (value: string, expiresAt: Date) => {
  cached = { value, expiresAt: expiresAt.getTime() - MARGIN_MS }
  return value
}

// A shared access token still worth using, if the document holds one.
const sharedAccess = ({ accessToken, expiresAt }: { accessToken?: string; expiresAt?: Date }) =>
  accessToken &&
  accessToken !== rejectedAccess &&
  expiresAt &&
  expiresAt.getTime() - MARGIN_MS > Date.now()
    ? { accessToken, expiresAt }
    : undefined

// Whether this instance has already reported a dead chain. Every recipe sheet asks
// the oven every thirty seconds, and a chain stays dead until someone re-provisions
// it — once is the signal, the rest is noise.
let reportedDeadChain = false

// Spend the refresh token under the claim. Electrolux rotates it on every use, so
// the configured secret is only a SEED and the live token is the stored one —
// hence the stored one first. The seed is tried second, which is what makes a dead
// chain RECOVERABLE: rotate the secret, redeploy, and the next call heals itself.
const refreshUnderClaim = async (
  settings: { apiKey: string; refreshToken: string },
  stored: string | undefined,
): Promise<string | 'access-expired'> => {
  const candidates = [stored, settings.refreshToken].filter(
    (token, index, all): token is string => !!token && all.indexOf(token) === index,
  )
  const pair = await spendFirst(settings.apiKey, candidates).catch(async (error) => {
    await releaseRefresh()
    throw error
  })

  if (pair === 'rejected') {
    await releaseRefresh()
    // Every token refused is an outcome, not a fault: the oven is fine, the access
    // to it is over until a new pair is generated on the developer portal.
    if (!reportedDeadChain) {
      reportedDeadChain = true
      Sentry.captureMessage('Electrolux rejected every refresh token: the chain needs a new pair')
    }
    return 'access-expired'
  }

  const lifetime = pair.expiresIn ? pair.expiresIn * 1000 : DEFAULT_LIFETIME_MS
  const expiresAt = new Date(Date.now() + lifetime)
  await rememberTokens({
    refreshToken: pair.refreshToken,
    accessToken: pair.accessToken,
    expiresAt,
  })
  reportedDeadChain = false
  rejectedAccess = undefined
  return remember(pair.accessToken, expiresAt)
}

// One look at the shared session: reuse its access token, or take the claim and
// refresh, or — while another instance holds the claim — wait for its result.
// `force` skips the reuse, for the keep-alive that exists to spend the chain.
const obtain = async (
  settings: { apiKey: string; refreshToken: string },
  force: boolean,
  attempt = 0,
): Promise<string | 'access-expired'> => {
  const stored = await storedTokens()
  const shared = force ? undefined : sharedAccess(stored)
  if (shared) return remember(shared.accessToken, shared.expiresAt)

  const claim = await claimRefresh(new Date(), LEASE_MS)
  if (claim !== 'busy') return refreshUnderClaim(settings, claim.refreshToken)

  // Another instance is spending the chain right now. Its result lands in the
  // shared document within the lease; a forced refresh is satisfied by it too.
  // Waiting longer than a lease is a fault, which the client reads as an oven out
  // of reach for this one call.
  if (attempt >= WAIT_ATTEMPTS) throw new Error('Gave up waiting for another Electrolux refresh')
  await new Promise((resolve) => setTimeout(resolve, WAIT_MS))
  return obtain(settings, false, attempt + 1)
}

export const accessToken = async ({
  force,
}: {
  force?: boolean
} = {}): Promise<string | 'not-configured' | 'access-expired'> => {
  const settings = config().electrolux
  if (!settings) return 'not-configured'
  if (!force && cached && cached.expiresAt > Date.now()) return cached.value
  return obtain(settings, force ?? false)
}

// Spend the chain now, whatever the cached tokens say. Run daily by Cloud Scheduler:
// a refresh token nobody spends for weeks may simply expire, and a chain kept in
// use is one that is never found dead on the evening a cook needs the oven.
export const keepSessionAlive = async () => {
  const outcome = await accessToken({ force: true })
  return outcome === 'not-configured' || outcome === 'access-expired'
    ? outcome
    : ('refreshed' as const)
}
