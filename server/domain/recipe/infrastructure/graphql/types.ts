import { bestRating, versionToOpen } from '~/domain/recipe/business-rules'
import { type RecipeLibraryPage, RecipeQuery } from '~/domain/recipe/query'
import { builder } from '~/domain/shared/graphql/builder'
import type { Ingredient, Recipe, RecipeVersion, ThermomixSettings } from '../../types'
import { DishCategoryEnum, RecipeTypeEnum, VersionOriginKindEnum } from './enums'

export const IngredientType = builder.objectRef<Ingredient>('Ingredient').implement({
  description:
    'One line of the ingredient list: what it is and how much of it. The list keeps its ' +
    'order, e.g. `"Flour — 250 g"`, then `"Butter — 100 g"`, then `"Eggs — 3"`.',
  fields: (t) => ({
    name: t.expose('name', {
      type: 'IngredientName',
      description: 'What the ingredient is, e.g. `"Flour"` or `"Fine salt"`',
    }),
    quantity: t.expose('quantity', {
      type: 'IngredientQuantity',
      description: 'How much of it, unit included, e.g. `"250 g"`, `"2 tbsp"`, `"1 pinch"`',
    }),
  }),
})

export const ThermomixSettingsType = builder
  .objectRef<ThermomixSettings>('ThermomixSettings')
  .implement({
    description:
      'The Thermomix machine settings that go with one step (only for Thermomix recipes). Every field ' +
      'is optional — a step can set just a speed, or a full time + temperature + speed combo, ' +
      'e.g. `"10 min / 100°C / speed 2"`.',
    fields: (t) => ({
      time: t.field({
        type: 'ThermomixTime',
        nullable: true,
        description: 'How long the step runs, e.g. `"10 min"` or `"30 s"` (`null` if not set)',
        resolve: (s) => s.time ?? null,
      }),
      temperature: t.field({
        type: 'ThermomixTemperature',
        nullable: true,
        description: 'The cooking temperature, e.g. `"100°C"` or `"Varoma"` (`null` if not set)',
        resolve: (s) => s.temperature ?? null,
      }),
      speed: t.field({
        type: 'ThermomixSpeed',
        nullable: true,
        description: 'The blade speed, e.g. `"2"`, `"kneading"`, `"turbo"` (`null` if not set)',
        resolve: (s) => s.speed ?? null,
      }),
      reverse: t.boolean({
        nullable: true,
        description:
          'Whether the blades spin in reverse (gentle mixing) — `true`/`false`, `null` if not set',
        resolve: (s) => s.reverse ?? null,
      }),
    }),
  })

// A version is also an attempt: immutable content/lineage, plus its outcome fields
// (rating/remarks/executedAt) written once when executed. `tried` derives from
// `executedAt`.
export const VersionType = builder.objectRef<RecipeVersion>('Version').implement({
  description:
    'One version of a recipe — and, at the same time, one attempt (a real cook in the ' +
    'kitchen). Two sides to it: the CONTENT (its ingredients and steps, frozen the moment the ' +
    'version is created) and the OUTCOME (its rating and remarks, filled in once you have ' +
    'actually cooked it). Versions form a chain: `v1 → v2 → v3` … Each new version builds on ' +
    'the one before, so you can see what changed and whether it made the dish better.',
  fields: (t) => ({
    recipeId: t.expose('recipeId', {
      type: 'RecipeId',
      description: 'Which recipe this version belongs to, e.g. the id of `"Grandma’s lasagna"`',
    }),
    number: t.expose('number', {
      type: 'VersionNumber',
      description:
        'Its rank in the chain — `1` is the original import, `2` the first tweak, and so on',
    }),
    createdAt: t.expose('createdAt', {
      type: 'DateTime',
      description:
        'When this version was created (not when it was cooked — see executedAt), e.g. ' +
        '`"2026-07-18T14:30:00.000Z"`',
    }),
    originKind: t.field({
      type: VersionOriginKindEnum,
      description: 'Where this version came from: the import, an AI suggestion, or written by hand',
      resolve: (v) => v.origin.kind,
    }),
    originDetail: t.string({
      nullable: true,
      description:
        'A short label about its origin, e.g. `"Marmiton"` (the site it was imported from), or ' +
        '`null` if none',
      resolve: (v) => v.origin.detail ?? null,
    }),
    change: t.exposeString('change', {
      nullable: true,
      description:
        'A short summary of what this version changes versus the previous one, e.g. `"Baked at ' +
        '180°C instead of 200°C"`. A dish or Thermomix recipe may change several things at once. ' +
        '`null` on the original `v1`, which changes nothing.',
    }),
    basedOn: t.field({
      type: 'VersionNumber',
      nullable: true,
      description:
        'The version this one iterates on — the attempt it was built from, e.g. `2` for a `v3` ' +
        'proposed after cooking `v2`. `null` on the original `v1`, which builds on nothing.',
      resolve: (v) => v.basedOn ?? null,
    }),
    why: t.string({
      nullable: true,
      description:
        'The reason behind that change, e.g. `"The top was burning at 200°C"`. `null` when not ' +
        'given.',
      resolve: (v) => v.why ?? null,
    }),
    ingredients: t.field({
      type: [IngredientType],
      description:
        'This version’s full ingredient list, in order, e.g. `"Flour — 250 g"` then ' +
        '`"Eggs — 3"` (empty list when it has none)',
      resolve: (v) => v.ingredients,
    }),
    steps: t.expose('steps', {
      type: ['StepText'],
      description:
        'This version’s method, one short instruction per step, in order, e.g. ' +
        '`"Fold in the egg whites"`',
    }),
    tmxSteps: t.field({
      type: [ThermomixSettingsType],
      description:
        'Per-step Thermomix settings aligned with steps, e.g. `"10 min / 100°C / speed 2"` ' +
        '(an entry with every field `null` = plain step; `[]` if not thermomix)',
      resolve: (v) => v.tmxSteps,
    }),
    executedAt: t.field({
      type: 'DateTime',
      nullable: true,
      description:
        'The day you actually cooked this version, e.g. `"2026-07-18T14:30:00.000Z"`. `null` ' +
        'means it is still a planned attempt (a to-do you have lined up but not tried yet).',
      resolve: (v) => v.executedAt ?? null,
    }),
    tried: t.boolean({
      description:
        'The quick yes/no of the field above: `true` once you have cooked and rated it, `false` ' +
        'while it is still waiting to be tried',
      resolve: (v) => v.executedAt !== undefined,
    }),
    rating: t.field({
      type: 'Rating',
      nullable: true,
      description:
        'Your rating of this attempt, from `1` (bad) to `5` (excellent). `null` until you have ' +
        'cooked it. The recipe’s best rating across its versions drives what it displays (see ' +
        'bestRating).',
      resolve: (v) => v.rating ?? null,
    }),
    remarks: t.field({
      type: 'Remarks',
      nullable: true,
      description:
        'Your free notes on how it turned out, e.g. `"Still a touch too sweet, but the texture ' +
        'is spot on"`. `null` until you have cooked it.',
      resolve: (v) => v.remarks ?? null,
    }),
    photoUrl: t.string({
      nullable: true,
      description:
        'A link to the photo of the result, e.g. `"https://…/lasagna.jpg"` (always `null` for ' +
        'now — photos aren’t stored yet)',
      resolve: () => null,
    }),
  }),
})

export const RecipeType = builder.objectRef<Recipe>('Recipe')

RecipeType.implement({
  description:
    'A dish you are perfecting over time. A recipe is the whole experiment, not a single ' +
    'recipe card: it holds a chain of versions (v1, v2, v3 …), each one an attempt in the ' +
    'kitchen. Its state is derived from that chain — its best rating (bestRating) and the version ' +
    'to open from the home (versionToOpen). Think `"Grandma’s lasagna"` and every attempt you ' +
    'have made to nail it.',
  fields: (t) => ({
    id: t.expose('id', {
      type: 'RecipeId',
      description: 'Its unique identifier, e.g. `"9f1c…-a3b2"`',
    }),
    type: t.expose('type', {
      type: RecipeTypeEnum,
      description: 'Whether it is a cooked dish (`DISH`) or a Thermomix recipe (`THERMOMIX`)',
    }),
    category: t.expose('category', {
      type: DishCategoryEnum,
      description:
        'Which course it is, e.g. `DESSERT` for a tarte tatin. Set once at import and shared by ' +
        'every version; used to group the library.',
    }),
    title: t.expose('title', {
      type: 'RecipeTitle',
      description: 'Its name, e.g. `"Grandma’s lasagna"`',
    }),
    createdAt: t.expose('createdAt', {
      type: 'DateTime',
      description: 'When the recipe was first imported, e.g. `"2026-07-18T14:30:00.000Z"`',
    }),
    updatedAt: t.expose('updatedAt', {
      type: 'DateTime',
      description:
        'When anything last changed on it (a new version, a rating…), e.g. ' +
        '`"2026-07-18T14:30:00.000Z"`. Drives library sort.',
    }),
    versionCount: t.expose('versionCount', {
      type: 'VersionNumber',
      description:
        'How many versions exist so far — also the number of the most recent one, e.g. `3` ' +
        'after `v1 → v2 → v3`',
    }),
    versions: t.field({
      type: [VersionType],
      description: 'The whole history, oldest first, e.g. `v1 → v2 → v3`',
      resolve: (r) => RecipeQuery.versionsOf(r.id),
    }),
    // Satellite: the version the recipe sheet opens on, derived from the full lineage via
    // the batched loader (shares the scan with bestRating — no extra reads).
    versionToOpen: t.field({
      type: VersionType,
      description:
        'The version to show first when you open this recipe: the attempt in progress (the most ' +
        'recent one built on your best-rated version), or that best-rated version itself, or — ' +
        'if you have never cooked any — the latest version. Never `null`; a recipe always has at ' +
        'least its `v1`.',
      resolve: async (r, _a, { loaders }) => {
        const versions = (await loaders.versionsByRecipe.load(r.id)) ?? []
        return versionToOpen(versions)
      },
    }),
    // Satellite: the recipe's best attempt rating across its cooked versions, from
    // the batched loader that groups the full lineage by recipe (no extra reads).
    bestRating: t.field({
      type: 'Rating',
      nullable: true,
      description:
        'The best rating this recipe ever got, across all the attempts you have cooked, e.g. ' +
        '`5` (`1`–`5`). `null` if you have never tried any version yet.',
      resolve: async (r, _a, { loaders }) => {
        const versions = (await loaders.versionsByRecipe.load(r.id)) ?? []
        return bestRating(versions)?.rating ?? null
      },
    }),
  }),
})

// A page of the recipe library. `totalCount` is the size of THIS page — the full
// library count is never computed (an infinite-scroll list, not a total).
export const RecipesType = builder.objectRef<RecipeLibraryPage>('Recipes').implement({
  description:
    'One slice of your recipe library — a single "page" of results, the way an app loads a few ' +
    'at a time as you scroll rather than everything at once.',
  fields: (t) => ({
    items: t.field({
      type: [RecipeType],
      description: 'The recipes on this page, e.g. `"Grandma’s lasagna"` then `"Tarte tatin"`',
      resolve: ({ items }) => items,
    }),
    hasMore: t.exposeBoolean('hasMore', {
      description:
        'Are there more recipes to load after this page? (`true` = keep scrolling, `false` = ' +
        'you have reached the end)',
    }),
    totalCount: t.exposeInt('totalCount', {
      description:
        'How many recipes are on THIS page, e.g. `20` — not the size of the whole library, ' +
        'which is never counted (the list is meant to be scrolled, not totalled)',
    }),
  }),
})
