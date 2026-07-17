import { DishCategoryEnum, RecipeTypeEnum } from '~/domain/recipe/infrastructure/graphql/enums'
import { builder } from '~/domain/shared/graphql/builder'
import type { ImportAnalysis, ImportTmxSettings } from '~/system/ai/types'

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

// Raw ingredient from the import analysis — plain strings, shown in the editable
// preview before the user confirms (values are validated into branded types on create).
type ImportIngredient = { name: string; quantity: string }

const ImportIngredientType = builder.objectRef<ImportIngredient>('ImportIngredient').implement({
  description: 'A recipe ingredient extracted by the AI (unvalidated preview)',
  fields: (t) => ({
    name: t.exposeString('name'),
    quantity: t.exposeString('quantity'),
  }),
})

const ImportTmxSettingsType = builder.objectRef<ImportTmxSettings>('ImportTmxSettings').implement({
  description: 'Thermomix settings for one step extracted by the AI (unvalidated preview)',
  fields: (t) => ({
    time: t.exposeString('time', { nullable: true }),
    temperature: t.exposeString('temperature', { nullable: true }),
    speed: t.exposeString('speed', { nullable: true }),
    reverse: t.exposeBoolean('reverse', { nullable: true }),
  }),
})

export const ImportAnalysisType = builder.objectRef<ImportAnalysis>('ImportAnalysis').implement({
  description: 'Structured recipe extracted from an import source (editable preview)',
  fields: (t) => ({
    type: t.expose('type', { type: RecipeTypeEnum }),
    category: t.expose('category', {
      type: DishCategoryEnum,
      description: 'The dish category detected by the AI',
    }),
    title: t.exposeString('title'),
    subtitle: t.exposeString('subtitle', { nullable: true }),
    sourceLabel: t.exposeString('sourceLabel', { nullable: true }),
    params: t.field({ type: [ImportParamType], resolve: (a) => a.params }),
    ingredients: t.field({ type: [ImportIngredientType], resolve: (a) => a.ingredients }),
    steps: t.exposeStringList('steps'),
    tmxSteps: t.field({
      type: [ImportTmxSettingsType],
      nullable: { list: true, items: true },
      description: 'Per-step Thermomix settings, aligned with steps (null = plain step)',
      resolve: (a) => a.tmxSteps ?? null,
    }),
  }),
})
