import { builder } from '~/domain/shared/graphql/builder'
import { DishCategoryEnum, RecipeTypeEnum } from './enums'

export const ParamInput = builder.inputType('ParamInput', {
  description: 'A recipe parameter (ordered)',
  fields: (t) => ({
    key: t.field({ type: 'ParamKey', required: true }),
    value: t.field({ type: 'ParamValue', required: true }),
  }),
})

export const IngredientInput = builder.inputType('IngredientInput', {
  description: 'A recipe ingredient with its quantity (ordered)',
  fields: (t) => ({
    name: t.field({ type: 'IngredientName', required: true }),
    quantity: t.field({ type: 'IngredientQuantity', required: true }),
  }),
})

export const TmxSettingsInput = builder.inputType('TmxSettingsInput', {
  description: 'Thermomix settings for one step (all optional)',
  fields: (t) => ({
    time: t.field({ type: 'TmxTime' }),
    temperature: t.field({ type: 'TmxTemperature' }),
    speed: t.field({ type: 'TmxSpeed' }),
    reverse: t.boolean({ required: false }),
  }),
})

export const CreateRecipeInput = builder.inputType('CreateRecipeInput', {
  description: 'Create a recipe (v1) from a confirmed import preview',
  fields: (t) => ({
    type: t.field({ type: RecipeTypeEnum, required: true }),
    category: t.field({
      type: DishCategoryEnum,
      required: true,
      description: 'The dish category detected at import',
    }),
    title: t.field({ type: 'RecipeTitle', required: true }),
    subtitle: t.field({ type: 'RecipeSubtitle' }),
    sourceLabel: t.string({ description: 'Where the recipe came from' }),
    params: t.field({ type: [ParamInput], required: true }),
    ingredients: t.field({
      type: [IngredientInput],
      required: { list: false, items: true },
      description: 'The recipe’s components with quantities',
    }),
    steps: t.field({ type: ['StepText'], required: true }),
    tmxSteps: t.field({
      type: [TmxSettingsInput],
      required: { list: false, items: false },
      description: 'Per-step Thermomix settings, aligned with steps (null = plain step)',
    }),
  }),
})

export const UpdateRecipeInput = builder.inputType('UpdateRecipeInput', {
  description: 'Update a recipe’s title and subtitle. Absent fields are unchanged.',
  fields: (t) => ({
    title: t.field({ type: 'RecipeTitle' }),
    subtitle: t.field({ type: 'RecipeSubtitle' }),
  }),
})
