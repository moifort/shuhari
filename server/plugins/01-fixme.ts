import { fixme } from 'fixme-nitro'

// DSN exposé via NITRO_FIXME_DSN (Secret Manager en prod — infra/secrets.tf +
// function.tf — et .env en local), suivant la convention NITRO_ du repo. Le SDK
// prend le dsn en argument explicite, il n'impose donc pas le nom brut FIXME_DSN.
//
// Only a real URL is forwarded: a blank or garbage value (e.g. a placeholder
// "-") is treated as "no reporting" instead of crashing the function at boot
// (a bad dsn fails the Cloud Run health check → the whole deploy fails).
const dsn = process.env.NITRO_FIXME_DSN
export default fixme({ dsn: dsn && /^https?:\/\//.test(dsn) ? dsn : undefined })
