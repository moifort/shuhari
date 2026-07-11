import { RecipeTypeEnum } from '~/domain/recipe/infrastructure/graphql/enums'
import { builder } from '~/domain/shared/graphql/builder'
import type { ImportAnalysis } from '~/system/ai/types'

// Raw parameter from the import analysis — plain strings, shown in the editable
// preview before the user confirms (and the values are validated into branded types).
type ImportParam = { key: string; value: string }

const ImportParamType = builder.objectRef<ImportParam>('ImportParam').implement({
  description: 'A recipe parameter extracted by the AI (unvalidated preview)',
  fields: (t) => ({
    key: t.exposeString('key'),
    value: t.exposeString('value'),
  }),
})

export const ImportAnalysisType = builder.objectRef<ImportAnalysis>('ImportAnalysis').implement({
  description: 'Structured recipe extracted from an import source (editable preview)',
  fields: (t) => ({
    type: t.expose('type', { type: RecipeTypeEnum }),
    title: t.exposeString('title'),
    subtitle: t.exposeString('subtitle', { nullable: true }),
    sourceLabel: t.exposeString('sourceLabel', { nullable: true }),
    params: t.field({ type: [ImportParamType], resolve: (a) => a.params }),
    steps: t.exposeStringList('steps'),
  }),
})
