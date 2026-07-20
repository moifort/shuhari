# GraphQL Best Practices (code-first)

Portable rules for a code-first GraphQL layer (Pothos + Apollo Server) over a DDD backend —
nothing here names this project. How this repo wires them is in
[graphql-patterns.md](graphql-patterns.md). Examples use a fictional `bean` domain.

## The schema lives with the domains, not in a central folder

Each bounded context owns its slice — `infrastructure/graphql/{enums,types,inputs,queries,mutations}.ts` —
and a small shared layer holds the plumbing only:

- **builder** — the single `SchemaBuilder`, the context type, the scalar map.
- **scalars** — registration of every branded scalar.
- **schema** — assembly by side-effect imports, in dependency order.
- **loaders** — the per-request batched loaders.

A central `graphql/` directory turns into a second, parallel model of the domain — and it drifts.

**Fields are non-null by default** (`defaultFieldNullability: false`): nullability is a deliberate,
explicit act, not the default the schema falls into.

## Validate at the boundary, once, through scalars

Every branded domain type is a scalar whose `parseValue` runs the domain's validation constructor
and converts a validation failure into a `BAD_USER_INPUT` error. This is Evans's Anti-Corruption
Layer: raw input is validated **here**, never again downstream.

```ts
builder.scalarType('BeanId', {
  description: 'Bean unique identifier (UUID v4)',
  serialize: (value) => value as string,
  parseValue: validatedParse('BeanId', BeanId),   // throws GraphQLError BAD_USER_INPUT
})
```

## Object types back domain models — never duplicate the shape

`objectRef<DomainType>('Name')` binds the GraphQL type to the domain shape; `t.expose` maps a field
straight through, `t.field({ resolve })` computes one. There is no DTO layer to keep in sync.

When a type is referenced before its full field set is known, or carries fields derived from another
collection, **declare the ref first and implement it separately**. That forward declaration is also
what lets another context graft a field onto it (`builder.objectField(BeanType, 'roasts', …)`)
without either context importing the other's internals.

## Derived fields have a read budget — batch them

A field derived from a satellite collection must **never** scan per parent row. It resolves through
a per-request, DataLoader-style batcher: memoize per key, collect every `load()` of the tick, flush
once, perform **one** keyed read.

Two consequences worth stating as rules:

- A page of N parents selecting a derived field costs **one** read, not N.
- An **unselected** derived field costs **nothing** — that is the point of resolving it lazily
  rather than assembling it eagerly in the query.

Assert both in integration tests as an explicit read budget. A doc that says "avoid N+1" is a wish;
a failing test is a rule.

## Resolvers are thin — validate, delegate, map

A resolver scopes to the authenticated user, calls the domain's `Query` / `Command` / `UseCase`,
and maps the result. Business logic in a resolver is business logic no other entry point can reuse
and no unit test can reach.

## Map sentinels to errors exhaustively

Commands return the entity or a string sentinel. Map them with an **exhaustive** pattern match —
never a catch-all `otherwise` — so a new sentinel is a compile error instead of a silent
fall-through. A single `never`-returning helper turns the sentinel into a transport error, deriving
the error code mechanically from the sentinel itself (`'not-found'` → `NOT_FOUND`), so every arm
reads `.with('<sentinel>', domainError)`.

```ts
return match(result)
  .with('not-found', domainError)
  .with(P.not(P.string), (bean) => bean)   // success arm: "not a sentinel"
  .exhaustive()
```

Guards *inside* a use-case (unwrapping a query result mid-flow) stay ordinary `if`s — the exhaustive
match is for mapping a **final** outcome.

## A domain union is a schema union; its input mirror is `@oneOf`

A field whose shape depends on a discriminant becomes a `unionType` whose `resolveType` reads the
backing model's tag — the domain's discriminant *is* the schema's.

On the input side the mirror is a `@oneOf` input (`isOneOf: true`, every arm optional): exactly one
arm may be set, and a small brancher turns the arms back into the domain's discriminated type.
Adding a variant then touches exactly three places — the union's `types`/`resolveType`, the `@oneOf`
field, the brancher — and the compiler finds all three.

Nested value objects get their own object ref rather than being flattened into the parent: a total
value object (`{}` meaning "nothing set") keeps the schema free of optional-array holes.

## Document every field, functionally, for a non-technical reader

Every type, field, enum value and argument carries a `description`. The SDL is the contract shared
with the client and the page people read in the API sandbox — an undocumented field is an
incomplete field.

Write descriptions in **business language**, as if the reader had never seen the code:

- **Say what it means in the domain, not what it is technically** — "The version to open first when
  you enter the recipe", not "The versionToOpen resolver".
- **Give a concrete example** with real domain values (`e.g. "250 g"`, `1 (bad) to 5 (excellent)`).
- **Explain nullability in plain words**: what does `null` *mean* here?
- **Cross-reference sibling fields by name**, so the reader can navigate the graph.
- **Flag destructive mutations** explicitly ("WARNING: this REPLACES everything…").
- Keep the domain vocabulary identical across the schema — it is the ubiquitous language on the
  wire.

## Change order: domain first, client last

1. Domain types and validation constructors.
2. The GraphQL slice (enums, types, inputs, queries, mutations).
3. Regenerate the SDL.
4. Regenerate the client's typed operations.

Going the other way — shaping the schema first and back-filling the domain — produces a schema that
mirrors the transport instead of the model.
