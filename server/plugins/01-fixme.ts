import { fixme } from 'fixme-nitro'

// DSN exposé via NITRO_FIXME_DSN (Secret Manager en prod — infra/secrets.tf +
// function.tf — et .env en local), suivant la convention NITRO_ du repo. Le SDK
// prend le dsn en argument explicite, il n'impose donc pas le nom brut FIXME_DSN.
export default fixme({ dsn: process.env.NITRO_FIXME_DSN })
