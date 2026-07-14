import * as Sentry from '@sentry/node'

// DSN exposé via NITRO_SENTRY_DSN (Secret Manager en prod — infra/secrets.tf +
// function.tf — et .env en local), suivant la convention NITRO_ du repo.
//
// Only a real URL is forwarded: a blank or garbage value (e.g. a placeholder
// "-") disables reporting instead of crashing the function at boot (a bad dsn
// fails the Cloud Run health check → the whole deploy fails).
const dsn = process.env.NITRO_SENTRY_DSN
const enabled = Boolean(dsn && /^https?:\/\//.test(dsn))

if (enabled) Sentry.init({ dsn })

export default defineNitroPlugin((nitroApp) => {
  if (!enabled) return
  // Only surface genuine server faults: expected 4xx (401 missing user, 404,
  // BAD_USER_INPUT) are business outcomes, not incidents.
  nitroApp.hooks.hook('error', (error) => {
    const statusCode = (error as { statusCode?: number }).statusCode
    if (statusCode && statusCode < 500) return
    Sentry.captureException(error)
  })
})
