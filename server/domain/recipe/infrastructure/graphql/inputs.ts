import { builder } from '~/domain/shared/graphql/builder'
import { DishCategoryEnum, RecipeTypeEnum } from './enums'

export const IngredientInput = builder.inputType('IngredientInput', {
  description: 'One ingredient line to save, e.g. name "Flour" + quantity "250 g". Order is kept.',
  fields: (t) => ({
    name: t.field({
      type: 'IngredientName',
      required: true,
      description: 'What it is, e.g. "Flour"',
    }),
    quantity: t.field({
      type: 'IngredientQuantity',
      required: true,
      description: 'How much, unit included, e.g. "250 g"',
    }),
  }),
})

export const TmxSettingsInput = builder.inputType('TmxSettingsInput', {
  description: 'The Thermomix settings to attach to one step. Every field is optional.',
  fields: (t) => ({
    time: t.field({ type: 'TmxTime', description: 'Duration, e.g. "10 min"' }),
    temperature: t.field({ type: 'TmxTemperature', description: 'Temperature, e.g. "100°C"' }),
    speed: t.field({ type: 'TmxSpeed', description: 'Blade speed, e.g. "2" or "turbo"' }),
    reverse: t.boolean({ required: false, description: 'Reverse (gentle mixing) on or off' }),
  }),
})

export const CreateRecipeInput = builder.inputType('CreateRecipeInput', {
  description:
    'Everything needed to save a brand-new recipe (its v1), once you have reviewed the import ' +
    'preview and confirmed it',
  fields: (t) => ({
    type: t.field({
      type: RecipeTypeEnum,
      required: true,
      description: 'Cooked dish or Thermomix recipe',
    }),
    category: t.field({
      type: DishCategoryEnum,
      required: true,
      description: 'Its course (starter, main…), as detected during import',
    }),
    title: t.field({ type: 'RecipeTitle', required: true, description: 'The recipe’s name' }),
    subtitle: t.field({ type: 'RecipeSubtitle', description: 'Optional one-line subtitle' }),
    sourceLabel: t.string({ description: 'Where it came from, e.g. a website name or "Mum"' }),
    ingredients: t.field({
      type: [IngredientInput],
      required: { list: false, items: true },
      description: 'The ingredient list, in order',
    }),
    steps: t.field({
      type: ['StepText'],
      required: true,
      description: 'The method, one instruction per step, in order',
    }),
    tmxSteps: t.field({
      type: [TmxSettingsInput],
      required: { list: false, items: false },
      description:
        'Thermomix settings lined up with the steps above — one entry per step, null for a step ' +
        'with no machine settings (only for TMX recipes)',
    }),
  }),
})

export const UpdateRecipeInput = builder.inputType('UpdateRecipeInput', {
  description:
    'Fields to rename a recipe. Send only what you want to change — anything you leave out stays ' +
    'as it was.',
  fields: (t) => ({
    title: t.field({
      type: 'RecipeTitle',
      description: 'The new name (leave out to keep the current one)',
    }),
    subtitle: t.field({
      type: 'RecipeSubtitle',
      description: 'The new subtitle (leave out to keep the current one)',
    }),
  }),
})

export const RecordEssaiInput = builder.inputType('RecordEssaiInput', {
  description:
    'The result of cooking one version: which version you tried, how you rate it, and your ' +
    'notes. Recorded once — a version’s outcome cannot be edited afterwards.',
  fields: (t) => ({
    recipeId: t.field({ type: 'RecipeId', required: true, description: 'Which recipe you cooked' }),
    versionNumber: t.field({
      type: 'VersionNumber',
      required: true,
      description: 'Which version of it you tried',
    }),
    note: t.field({ type: 'Note', required: true, description: 'Your rating, 1 to 5' }),
    remarks: t.field({
      type: 'Remarks',
      required: true,
      description: 'Your notes on how it turned out',
    }),
    // Placeholder: accepted but not yet persisted — recordEssai always stores
    // photoPath: null and photoUrl resolves null until GCS photo storage is
    // provisioned. Kept on the contract so the app can send it without a schema change.
    photo: t.string({ description: 'Base64 JPEG of the result (optional; not yet stored)' }),
  }),
})
