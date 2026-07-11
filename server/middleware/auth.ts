import { getAuth } from 'firebase-admin/auth'
import { UserId } from '~/domain/shared/primitives'
// Side-effect import: ensures firebase-admin is initialized before verifyIdToken.
import '~/system/firebase'
import { config } from '~/system/config'

export default defineEventHandler(async (event) => {
  const path = event.path ?? ''

  // Admin endpoints (separate token, never a Firebase user)
  if (path.startsWith('/admin/')) {
    const auth = getHeader(event, 'authorization')
    const adminToken = config().adminToken
    if (!adminToken || auth !== `Bearer ${adminToken}`)
      throw createError({ statusCode: 401, statusMessage: 'Unauthorized' })
    return
  }

  // Everything else (incl. /graphql): require a valid Firebase ID token.
  const auth = getHeader(event, 'authorization')
  const token = auth?.startsWith('Bearer ') ? auth.slice(7) : null
  if (!token) throw createError({ statusCode: 401, statusMessage: 'Missing bearer token' })

  try {
    const decoded = await getAuth().verifyIdToken(token)
    event.context.userId = UserId(decoded.uid)
  } catch {
    throw createError({ statusCode: 401, statusMessage: 'Invalid token' })
  }
})

declare module 'h3' {
  interface H3EventContext {
    userId?: ReturnType<typeof UserId>
  }
}
