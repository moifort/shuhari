import { highestNote, pendingEssais } from '~/domain/recipe/business-rules'
import { type RecipeLibraryPage, RecipeQuery } from '~/domain/recipe/query'
import { builder } from '~/domain/shared/graphql/builder'
import type { Ingredient, Recipe, RecipeVersion, TmxSettings } from '../../types'
import { DishCategoryEnum, RecipeTypeEnum, VersionOriginKindEnum } from './enums'

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

// A version is also an essai: immutable content/lineage, plus its outcome fields
// (note/remarks/executedAt) written once when executed. `tried` derives from
// `executedAt`.
export const VersionType = builder.objectRef<RecipeVersion>('Version').implement({
  description: 'A recipe version — an entry in the lineage (v1 → v2 → …) that is also an essai',
  fields: (t) => ({
    recipeId: t.expose('recipeId', { type: 'RecipeId' }),
    number: t.expose('number', { type: 'VersionNumber' }),
    createdAt: t.expose('createdAt', { type: 'DateTime' }),
    originKind: t.field({ type: VersionOriginKindEnum, resolve: (v) => v.origin.kind }),
    originDetail: t.string({ nullable: true, resolve: (v) => v.origin.detail ?? null }),
    change: t.exposeString('change', { nullable: true }),
    why: t.string({ nullable: true, resolve: (v) => v.why ?? null }),
    ingredients: t.field({
      type: [IngredientType],
      description: 'The recipe’s components with quantities ([] when none)',
      resolve: (v) => v.ingredients,
    }),
    steps: t.expose('steps', { type: ['StepText'] }),
    tmxSteps: t.field({
      type: [TmxSettingsType],
      nullable: { list: false, items: true },
      description:
        'Per-step Thermomix settings aligned with steps (null = plain step; [] if not tmx)',
      resolve: (v) => v.tmxSteps,
    }),
    executedAt: t.field({
      type: 'DateTime',
      nullable: true,
      description: 'When the essai was executed, or null while still an "essai à faire"',
      resolve: (v) => v.executedAt ?? null,
    }),
    tried: t.boolean({
      description: 'Whether this version has been executed (its essai recorded)',
      resolve: (v) => v.executedAt !== null,
    }),
    note: t.field({
      type: 'Note',
      nullable: true,
      description: 'The essai rating, or null while not yet executed',
      resolve: (v) => v.note ?? null,
    }),
    remarks: t.field({
      type: 'Remarks',
      nullable: true,
      description: 'The essai remarks, or null while not yet executed',
      resolve: (v) => v.remarks ?? null,
    }),
    photoUrl: t.string({
      nullable: true,
      description: 'Signed URL of the essai photo (null until photo storage is provisioned)',
      resolve: () => null,
    }),
  }),
})

export const RecipeType = builder.objectRef<Recipe>('Recipe')

RecipeType.implement({
  description: 'A recipe under experimentation, with its version lineage',
  fields: (t) => ({
    id: t.expose('id', { type: 'RecipeId' }),
    type: t.expose('type', { type: RecipeTypeEnum }),
    category: t.expose('category', {
      type: DishCategoryEnum,
      description: 'The dish category — fixed at import, shared across all versions',
    }),
    title: t.expose('title', { type: 'RecipeTitle' }),
    subtitle: t.string({ nullable: true, resolve: (r) => r.subtitle ?? null }),
    createdAt: t.expose('createdAt', { type: 'DateTime' }),
    updatedAt: t.expose('updatedAt', { type: 'DateTime' }),
    versionCount: t.expose('versionCount', {
      type: 'VersionNumber',
      description: 'How many versions the recipe has (its highest version number)',
    }),
    currentVersion: t.field({
      type: VersionType,
      nullable: true,
      description: 'The current reproducible reference version, or null until the first promotion',
      resolve: (r, _a, { loaders }) =>
        r.currentVersion === null
          ? null
          : loaders.version
              .load({ recipeId: r.id, number: r.currentVersion })
              .then((v) => v ?? null),
    }),
    toTest: t.field({
      type: VersionType,
      nullable: true,
      description: 'The pending version awaiting an essai, if any',
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
    pendingEssais: t.field({
      type: [VersionType],
      description:
        'Versions still awaiting their first run, most recent first — empty for a recipe that only holds its original version',
      resolve: (r) =>
        r.versionCount <= 1 ? [] : RecipeQuery.versionsOf(r.id).then((vs) => pendingEssais(vs)),
    }),
    // Satellite: the recipe's best essai note across its executed versions, from
    // the batched loader that groups the full lineage by recipe (no extra reads).
    bestNote: t.field({
      type: 'Note',
      nullable: true,
      description: 'The highest essai note the recipe ever scored, or null if never tried',
      resolve: async (r, _a, { loaders }) => {
        const versions = (await loaders.versionsByRecipe.load(r.id)) ?? []
        const notes = versions
          .map((v) => v.note)
          .filter((note): note is NonNullable<typeof note> => note !== null)
        return highestNote(notes)
      },
    }),
  }),
})

// A page of the recipe library. `totalCount` is the size of THIS page — the full
// library count is never computed (an infinite-scroll list, not a total).
export const RecipesType = builder.objectRef<RecipeLibraryPage>('Recipes').implement({
  description: 'A page of the recipe library',
  fields: (t) => ({
    items: t.field({ type: [RecipeType], resolve: ({ items }) => items }),
    hasMore: t.exposeBoolean('hasMore', {
      description: 'Whether more recipes are available after this page',
    }),
    totalCount: t.exposeInt('totalCount', {
      description: 'Number of recipes in this page (the full library count is not computed)',
    }),
  }),
})
