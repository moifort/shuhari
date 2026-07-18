import { DishCategoryEnum, RecipeTypeEnum } from '~/domain/recipe/infrastructure/graphql/enums'
import { IngredientType, TmxSettingsType } from '~/domain/recipe/infrastructure/graphql/types'
import { builder } from '~/domain/shared/graphql/builder'
import type { ImportAnalysis, ImportTmxSettings } from '~/system/ai/types'
import type { Proposition } from '../../types'

export const PropositionType = builder.objectRef<Proposition>('Proposition').implement({
  description:
    'The AI’s suggestion for your next attempt, e.g. `"Less sugar, longer resting time"`. After ' +
    'an essai, the AI reads your rating and notes and proposes a tweaked version. It is just a ' +
    'proposal shown on screen — nothing is saved until you accept it (see acceptProposition).',
  fields: (t) => ({
    basedOn: t.expose('basedOn', {
      type: 'VersionNumber',
      description:
        'The version this proposal iterates on (the one you just cooked), e.g. `2`. Sent straight ' +
        'back on accept so the new version records what it was based on.',
    }),
    changeSummary: t.exposeString('changeSummary', {
      description:
        'A one-line summary of what it changes, e.g. `"Less sugar, longer resting time"`',
    }),
    rationale: t.exposeString('rationale', {
      description:
        'The AI’s reasoning — why it thinks this change will help, based on your last notes, e.g. ' +
        '`"You noted it was too sweet, so cutting the sugar should balance it"`',
    }),
    ingredients: t.field({
      type: [IngredientType],
      description:
        'The complete ingredient list of the suggested version, e.g. `"Sugar — 80 g"` (not just ' +
        'what changed)',
      resolve: (d) => d.ingredients,
    }),
    steps: t.expose('steps', {
      type: ['StepText'],
      description:
        'The complete method of the suggested version, e.g. `"Rest the dough for 2 h"` (not just ' +
        'what changed)',
    }),
    tmxSteps: t.field({
      type: [TmxSettingsType],
      nullable: { list: false, items: true },
      description:
        'Per-step Thermomix settings aligned with steps, e.g. `"10 min / 100°C / speed 2"` ' +
        '(`null` = plain step; `[]` if not tmx)',
      resolve: (d) => d.tmxSteps,
    }),
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
