import { builder } from '~/domain/shared/graphql/builder'
import type { ImportResult } from '~/system/portability/types'

export const ImportResultType = builder.objectRef<ImportResult>('ImportResult').implement({
  description:
    'A tally of what was restored after an import — how many rows of each kind were loaded, ' +
    'e.g. `12` recipes and `37` versions',
  fields: (t) => ({
    recipes: t.exposeInt('recipes', {
      description: 'How many recipes were imported, e.g. `12`',
    }),
    versions: t.exposeInt('versions', {
      description: 'How many versions (across all those recipes) were imported, e.g. `37`',
    }),
  }),
})
