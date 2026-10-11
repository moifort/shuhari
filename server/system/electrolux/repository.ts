import { db } from '~/system/firebase'
import { genericDataConverter, transactionally } from '~/utils/firestore'

// The one document the oven integration persists. A standalone system doc, like the
// AI's analysis cache: it belongs to no domain and outlives no aggregate.
const SYSTEM_COLLECTION = 'system'
const TOKEN_DOC = 'electrolux'

// Everything the instances share about the Electrolux session. The access token
// lives here too, not only in each instance's memory: an instance that finds a
// valid one reuses it instead of spending the refresh token, so the chain is spent
// once per hour for the whole deployment rather than once per instance.
export type TokenDoc = {
  refreshToken?: string
  accessToken?: string
  expiresAt?: Date
  // Set while one instance is spending the refresh token. Electrolux rotates it on
  // every use, so two instances spending the same one at once is how a chain dies.
  refreshingUntil?: Date
}

const tokenRef = () =>
  db().collection(SYSTEM_COLLECTION).withConverter(genericDataConverter<TokenDoc>()).doc(TOKEN_DOC)

export const storedTokens = async (): Promise<TokenDoc> => (await tokenRef().get()).data() ?? {}

// Claim the right to spend the refresh token, for `leaseMs`. `busy` when another
// instance holds an unexpired claim; the claim lapses on its own, so an instance
// that dies mid-refresh never locks the chain for good.
export const claimRefresh = (now: Date, leaseMs: number) =>
  transactionally(async (tx) => {
    const current = (await tx.get(tokenRef())).data() ?? {}
    if (current.refreshingUntil && current.refreshingUntil > now) return 'busy' as const
    tx.set(tokenRef(), { ...current, refreshingUntil: new Date(now.getTime() + leaseMs) })
    return { outcome: 'claimed' as const, refreshToken: current.refreshToken }
  })

// Store a fresh pair and release the claim, in one write.
export const rememberTokens = async (tokens: {
  refreshToken: string
  accessToken: string
  expiresAt: Date
}) => {
  await tokenRef().set(tokens)
}

// Release the claim without a new pair — every token was refused. The refresh token
// stays where it was: it is dead, but it is the trace of where the chain stopped.
export const releaseRefresh = async () => {
  const {
    refreshingUntil: _released,
    accessToken: _stale,
    expiresAt: _gone,
    ...kept
  } = await storedTokens()
  await tokenRef().set(kept)
}
