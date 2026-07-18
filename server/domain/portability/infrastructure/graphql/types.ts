import type { ImportResult } from '~/domain/portability/types'
import { builder } from '~/domain/shared/graphql/builder'

export const ImportResultType = builder.objectRef<ImportResult>('ImportResult').implement({
  description:
    'A tally of what was restored after an import — how many rows of each kind were loaded',
  fields: (t) => ({
    recipes: t.exposeInt('recipes', { description: 'How many recipes were imported' }),
    versions: t.exposeInt('versions', {
      description: 'How many versions (across all those recipes) were imported',
    }),
  }),
})
