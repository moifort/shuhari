import type { ImportResult } from '~/domain/portability/types'
import { builder } from '~/domain/shared/graphql/builder'

export const ImportResultType = builder.objectRef<ImportResult>('ImportResult').implement({
  description: 'Number of records imported per collection',
  fields: (t) => ({
    recipes: t.exposeInt('recipes'),
    versions: t.exposeInt('versions'),
  }),
})
