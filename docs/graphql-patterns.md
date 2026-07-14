# GraphQL Patterns

Shuhari is GraphQL-first: a single endpoint `POST /graphql` (Apollo Server 5 + Pothos 4,
code-first). There is **no REST CRUD** — the only other HTTP route is `POST /admin/migrate`.
This guide covers how the schema is built and the conventions to follow.

> Prefer the repo's `graphql-pothos` skill for the authoritative, task-level checklist. This
> doc is the architectural overview and the shuhari-specific rules.

## Layout — per-domain slices + shared plumbing

There is **no central `server/graphql/`**. Each domain owns its slice:

```
server/domain/{domain}/infrastructure/graphql/
├── enums.ts      # builder.enumType(...)
├── types.ts      # builder.objectRef<T>('Name').implement(...)
├── inputs.ts     # builder.inputType(...)
├── queries.ts    # builder.queryField(...)
└── mutations.ts  # builder.mutationField(...)
```

The shared plumbing lives in `server/domain/shared/graphql/`:

- **builder.ts** — the single `SchemaBuilder`, the `GraphQLContext`, and the branded `Scalars` map.
- **scalars.ts** — registers each branded scalar.
- **schema.ts** — assembles everything by side-effect imports; exports `schema`.
- **loaders.ts** — per-request satellite loaders.

The server is booted once in `server/plugins/02-graphql.ts`
(`new ApolloServer({ schema, introspection: true })`, stored via `setApollo`), and each request
gets a fresh context in `server/routes/graphql.ts`.

## The Builder and Context

```ts
export type GraphQLContext = {
  event: H3Event
  userId: UserId
  loaders: RecipeSatelliteLoaders
}

export const builder = new SchemaBuilder<{
  Context: GraphQLContext
  DefaultFieldNullability: false
  Scalars: {
    DateTime: { Input: Date; Output: Date }
    RecipeId: { Input: RecipeId; Output: RecipeId }
    Note: { Input: Note; Output: Note }
    // …one entry per branded scalar
  }
}>({ defaultFieldNullability: false })

builder.addScalarType('DateTime', DateTimeScalar)
builder.queryType({})
builder.mutationType({})
```

`defaultFieldNullability: false` means fields are **non-null by default** — mark optional fields
`nullable: true` explicitly.

`userId` comes from the authenticated Firebase context (`middleware/auth.ts`); every resolver
scopes its data access to it.

## Branded Scalars — validation at the boundary

Each branded type is a GraphQL scalar. Its `parseValue` runs the domain's Zod constructor
through `validatedParse`, which converts a `ZodError` into a `BAD_USER_INPUT` `GraphQLError`.
This is the Anti-Corruption Layer: raw input is validated **once**, here.

```ts
const validatedParse =
  <T>(name: string, parse: (value: unknown) => T) =>
  (value: unknown): T => {
    try {
      return parse(value)
    } catch (error) {
      const message =
        error instanceof ZodError
          ? error.issues.map(({ message }) => message).join(', ')
          : `Invalid ${name}`
      throw new GraphQLError(`Invalid value for ${name}: ${message}`, {
        extensions: { code: 'BAD_USER_INPUT' },
      })
    }
  }

builder.scalarType('RecipeId', {
  description: 'Recipe unique identifier (UUID v4)',
  serialize: (value) => value as string,
  parseValue: validatedParse('RecipeId', RecipeId),
})
```

Adding a new scalar: declare it in the `Scalars` map (builder.ts) and register it (scalars.ts).

## Object Types back domain models

Pothos objects reference domain types as backing models via `objectRef<T>` — no type
duplication. `t.expose(...)` maps a field directly; `t.field({ resolve })` computes one.

```ts
export const ParamType = builder.objectRef<Param>('Param').implement({
  fields: (t) => ({
    key: t.expose('key', { type: 'ParamKey' }),
    value: t.expose('value', { type: 'ParamValue' }),
  }),
})
```

### Recursion / satellite grafting: declare then implement

When a type has recursive fields or receives satellite fields from other domains, declare the
`objectRef` first and `.implement()` it separately (Pothos recursion pattern):

```ts
export const RecipeType = builder.objectRef<Recipe>('Recipe')

RecipeType.implement({
  fields: (t) => ({
    id: t.expose('id', { type: 'RecipeId' }),
    variations: t.field({
      type: [RecipeType],                      // recursive self-reference
      resolve: (r, _a, { loaders }) => loaders.variations.load(r.id).then((v) => v ?? []),
    }),
  }),
})
```

Other domains then **graft** fields onto it with `builder.objectField`. Example — the `trial`
domain adds `Recipe.trials` and per-version aggregates, all served by the same batched loader:

```ts
builder.objectField(RecipeType, 'trials', (t) =>
  t.field({
    type: [TrialType],
    resolve: (recipe, _a, { loaders }) => loaders.trials.load(recipe.id).then((v) => v ?? []),
  }),
)

builder.objectField(VersionType, 'trialCount', (t) =>
  t.int({
    resolve: async (version, _a, { loaders }) => {
      const trials = (await loaders.trials.load(version.recipeId)) ?? []
      return trials.filter((trial) => trial.versionNumber === version.number).length
    },
  }),
)
```

## Satellite Loaders — the N+1 budget

Satellite fields (`currentVersion`, `toTest`, `trials`, `pendingProposal`, `variations`) must
**never** scan a collection or read one doc per parent row. They resolve through per-request
loaders (`server/domain/shared/graphql/loaders.ts`), built once per request in
`recipeSatelliteLoaders(userId)`.

`batchedBy` is a DataLoader-style batcher: it memoizes per key, collects every `load(...)` call
in the resolution tick, flushes on `process.nextTick`, and performs **one keyed read** per batch.

```ts
version: batchedBy(versionKey, async (refs) => {
  const versions = await RecipeQuery.versionsByRefs(refs)   // one getAll for the whole page
  return new Map(versions.map((v) => [versionKey({ recipeId: v.recipeId, number: v.number }), v]))
}),
```

So a page of recipes selecting `currentVersion` costs **one** `getAll`; an unselected satellite
costs **nothing**. Multiple aggregates (`Version.trialCount`, `Version.averageNote`) reuse the
same `trials` loader — still one read. These budgets are asserted in `.int.test.ts` via
`fake.queryReads` / `fake.docReads` — keep them green.

## Queries and Mutations delegate to the domain

Resolvers are thin: validate/scope, call `Query`/`Command`/`UseCase`, map the result.

```ts
builder.queryField('recipes', (t) =>
  t.field({
    type: [RecipeType],
    args: { type: t.arg({ type: RecipeTypeEnum }) },
    resolve: async (_root, { type }, { userId }) => {
      const recipes = await RecipeQuery.all(userId)
      return type ? recipes.filter((recipe) => recipe.type === type) : recipes
    },
  }),
)
```

## Mapping Sentinels to GraphQLError

Commands return the entity or a **string sentinel**. Map the sentinel to a `GraphQLError` with a
stable `extensions.code` using `match().exhaustive()` from `ts-pattern` and the `never`-returning
helpers from `server/domain/shared/graphql/errors.ts` — never `.otherwise()`, so adding a new
sentinel becomes a compile error rather than a silent fall-through. The success arm matches "not a
string" (`P.not(P.string)`):

```ts
import { match, P } from 'ts-pattern'
import { domainError, notFound } from '~/domain/shared/graphql/errors'

builder.mutationField('promoteVersion', (t) =>
  t.field({
    type: RecipeType,
    args: {
      recipeId: t.arg({ type: 'RecipeId', required: true }),
      versionNumber: t.arg({ type: 'VersionNumber', required: true }),
    },
    resolve: async (_root, { recipeId, versionNumber }, { userId }) => {
      const result = await RecipeCommand.promote(userId, recipeId, versionNumber)
      return match(result)
        .with('not-found', () => notFound('Recipe not found'))
        .with('nothing-to-test', () => domainError('NOTHING_TO_TEST', 'No version awaiting a trial'))
        .with(P.not(P.string), (recipe) => recipe)
        .exhaustive()
    },
  }),
)
```

A delete returns a `Boolean` and matches `undefined` (the command's success value):

```ts
return match(result)
  .with('not-found', () => notFound('Recipe not found'))
  .with(undefined, () => true)
  .exhaustive()
```

> **Note.** The narrowing guards *inside* use-cases (`if (recipe === 'not-found') return
> 'not-found'`, then continue with the narrowed value) stay as `if` — they unwrap a query result
> mid-flow rather than mapping a final outcome. See [error-handling.md](./error-handling.md).

## Inputs

`builder.inputType(...)`, backed by branded scalars. Optional fields are simply not `required`;
Pothos hands them back as `null | undefined`, so drop absent keys when mapping to the command.

```ts
export const UpdateRecipeInput = builder.inputType('UpdateRecipeInput', {
  fields: (t) => ({
    title: t.field({ type: 'RecipeTitle' }),
    subtitle: t.field({ type: 'RecipeSubtitle' }),
  }),
})
```

## Document everything

Every type, field, enum and argument gets a Pothos `description` — the SDL is the contract shared
with the iOS app and shows up in Apollo Sandbox. An undocumented field is an incomplete field.

## Regenerating the SDL and iOS types

The SDL is the contract shared with the iOS app (`shared/schema.graphql`).

```bash
bun run generate:graphql            # regenerate shared/schema.graphql
cd ios && apollo-ios-cli generate   # regenerate Generated/GraphQL from the SDL
```

Order of changes: **domain first** (types/primitives) → GraphQL slice → regenerate SDL → iOS
codegen. See [ios-guide.md](./ios-guide.md) for the client side.
