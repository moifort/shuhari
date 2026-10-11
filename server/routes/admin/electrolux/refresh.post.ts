import { keepSessionAlive } from '~/system/electrolux'

// The daily keep-alive of the Electrolux token chain, called by Cloud Scheduler
// behind the admin token. A dead chain answers 500 so the scheduler records the
// failure — Sentry has already been told by the token module.
export default defineEventHandler(async (event) => {
  const outcome = await keepSessionAlive()
  if (outcome === 'access-expired') setResponseStatus(event, 500)
  return { outcome }
})
