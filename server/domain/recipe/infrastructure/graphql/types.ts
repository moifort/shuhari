import { match } from 'ts-pattern'
import { RecipeQuery } from '~/domain/recipe/query'
import { builder } from '~/domain/shared/graphql/builder'
import type { Ingredient, Param, Recipe, RecipeVersion, TmxSettings } from '../../types'
import { RecipeTypeEnum, VersionOriginKindEnum } from './enums'

export const ParamType = builder.objectRef<Param>('Param').implement({
  description: 'A single recipe parameter (ordered list preserves display order)',
  fields: (t) => ({
    key: t.expose('key', { type: 'ParamKey' }),
    value: t.expose('value', { type: 'ParamValue' }),
  }),
})

export const IngredientType = builder.objectRef<Ingredient>('Ingredient').implement({
  description: 'A recipe component with its measured quantity (ordered list)',
  fields: (t) => ({
    name: t.expose('name', { type: 'IngredientName' }),
    quantity: t.expose('quantity', { type: 'IngredientQuantity' }),
  }),
})

export const TmxSettingsType = builder.objectRef<TmxSettings>('TmxSettings').implement({
  description: 'Thermomix settings for one step (display-oriented, all optional)',
  fields: (t) => ({
    time: t.field({ type: 'TmxTime', nullable: true, resolve: (s) => s.time ?? null }),
    temperature: t.field({
      type: 'TmxTemperature',
      nullable: true,
      resolve: (s) => s.temperature ?? null,
    }),
    speed: t.field({ type: 'TmxSpeed', nullable: true, resolve: (s) => s.speed ?? null }),
    reverse: t.boolean({ nullable: true, resolve: (s) => s.reverse ?? null }),
  }),
})

// Satellite fields averageNote / trialCount are grafted on by the trial domain.
export const VersionType = builder.objectRef<RecipeVersion>('Version').implement({
  description: 'An immutable entry in a recipe’s linear lineage (v1 → v2 → …)',
  fields: (t) => ({
    number: t.expose('number', { type: 'VersionNumber' }),
    createdAt: t.expose('createdAt', { type: 'DateTime' }),
    originKind: t.field({ type: VersionOriginKindEnum, resolve: (v) => v.origin.kind }),
    originDetail: t.string({ nullable: true, resolve: (v) => v.origin.detail ?? null }),
    change: t.exposeString('change', { nullable: true }),
    changedKeys: t.expose('changedKeys', { type: ['ParamKey'] }),
    why: t.string({ nullable: true, resolve: (v) => v.why ?? null }),
    params: t.field({ type: [ParamType], resolve: (v) => v.params }),
    ingredients: t.field({
      type: [IngredientType],
      nullable: { list: true, items: false },
      description: 'The recipe’s components with quantities (absent when none)',
      resolve: (v) => v.ingredients ?? null,
    }),
    steps: t.expose('steps', { type: ['StepText'] }),
    tmxSteps: t.field({
      type: [TmxSettingsType],
      nullable: { list: true, items: true },
      description: 'Per-step Thermomix settings, aligned with steps (null = plain step)',
      resolve: (v) => v.tmxSteps ?? null,
    }),
  }),
})

// Satellite fields trials / pendingProposal are grafted on by their own domains.
// Declared then implemented separately so the recursive derivedFrom/variations
// fields can reference the ref without TS inferring `any` (Pothos recursion pattern).
export const RecipeType = builder.objectRef<Recipe>('Recipe')

RecipeType.implement({
  description: 'A recipe under experimentation, with its version lineage',
  fields: (t) => ({
    id: t.expose('id', { type: 'RecipeId' }),
    type: t.expose('type', { type: RecipeTypeEnum }),
    title: t.expose('title', { type: 'RecipeTitle' }),
    subtitle: t.string({ nullable: true, resolve: (r) => r.subtitle ?? null }),
    createdAt: t.expose('createdAt', { type: 'DateTime' }),
    updatedAt: t.expose('updatedAt', { type: 'DateTime' }),
    currentVersion: t.field({
      type: VersionType,
      nullable: true,
      description: 'The current reproducible reference version',
      resolve: (r, _a, { loaders }) =>
        loaders.version.load({ recipeId: r.id, number: r.currentVersion }).then((v) => v ?? null),
    }),
    toTest: t.field({
      type: VersionType,
      nullable: true,
      description: 'The pending version awaiting a trial, if any',
      resolve: (r, _a, { loaders }) =>
        r.toTest === null
          ? null
          : loaders.version.load({ recipeId: r.id, number: r.toTest }).then((v) => v ?? null),
    }),
    versions: t.field({
      type: [VersionType],
      description: 'The full lineage, oldest first',
      resolve: (r) => RecipeQuery.versionsOf(r.id),
    }),
    derivedFrom: t.field({
      type: RecipeType,
      nullable: true,
      description: 'The parent recipe when this is a variation',
      resolve: (r, _a, { userId }) =>
        r.derivedFrom === null
          ? null
          : RecipeQuery.byId(userId, r.derivedFrom).then((res) =>
              match(res)
                .with('not-found', () => null)
                .otherwise((found) => found),
            ),
    }),
    variations: t.field({
      type: [RecipeType],
      description: 'Recipes derived from this one',
      resolve: (r, _a, { loaders }) => loaders.variations.load(r.id).then((v) => v ?? []),
    }),
  }),
})
