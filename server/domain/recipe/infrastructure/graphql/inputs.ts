import { builder } from '~/domain/shared/graphql/builder'
import { RecipeTypeEnum } from './enums'

export const ParamInput = builder.inputType('ParamInput', {
  description: 'A recipe parameter (ordered)',
  fields: (t) => ({
    key: t.field({ type: 'ParamKey', required: true }),
    value: t.field({ type: 'ParamValue', required: true }),
  }),
})

export const CreateRecipeInput = builder.inputType('CreateRecipeInput', {
  description: 'Create a recipe (v1) from a confirmed import preview',
  fields: (t) => ({
    type: t.field({ type: RecipeTypeEnum, required: true }),
    title: t.field({ type: 'RecipeTitle', required: true }),
    subtitle: t.field({ type: 'RecipeSubtitle' }),
    sourceLabel: t.string({ description: 'Where the recipe came from' }),
    params: t.field({ type: [ParamInput], required: true }),
    steps: t.field({ type: ['StepText'], required: true }),
  }),
})

export const UpdateRecipeInput = builder.inputType('UpdateRecipeInput', {
  description: 'Update a recipe’s title and subtitle. Absent fields are unchanged.',
  fields: (t) => ({
    title: t.field({ type: 'RecipeTitle' }),
    subtitle: t.field({ type: 'RecipeSubtitle' }),
  }),
})
