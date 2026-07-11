import { ParamInput } from '~/domain/recipe/infrastructure/graphql/inputs'
import { builder } from '~/domain/shared/graphql/builder'

export const RecordTrialInput = builder.inputType('RecordTrialInput', {
  description: 'Record one execution of a recipe version',
  fields: (t) => ({
    recipeId: t.field({ type: 'RecipeId', required: true }),
    versionNumber: t.field({ type: 'VersionNumber', required: true }),
    note: t.field({ type: 'Note', required: true }),
    remarks: t.field({ type: 'Remarks', required: true }),
    realParams: t.field({
      type: [ParamInput],
      required: true,
      description: 'The parameters actually used (server keeps only the deviations)',
    }),
    photo: t.string({ description: 'Base64 JPEG of the result (optional)' }),
  }),
})
