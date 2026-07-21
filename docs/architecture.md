# Backend Architecture

## Overview

The backend follows a strict Domain-Driven Design (DDD) / CQRS architecture built on
[Nitro](https://nitro.build/) (preset `firebase`, Firebase Cloud Functions Gen 2), with
TypeScript, **native Firestore** storage (`firebase-admin`), branded types, and a single
GraphQL endpoint (Apollo Server + Pothos).

## The rules behind it

The DDD/CQRS rules this structure implements — bounded-context layout, sentinels over exceptions,
private repositories, pure business rules, derived reads — are written project-agnostically in
[ddd-best-practices.md](./ddd-best-practices.md). This document only describes **where** they land
here. Most of them are **enforced by `server/architecture.unit.test.ts`**, the executable source of
truth; the style rules that go with them are in the [code style guide](./code-style.md).

Concretely, in this repo: a bounded context is `server/domain/{domain}/`; Value Objects and Entities
are the branded types in `types.ts`; the Anti-Corruption Layer is the Zod validation carried by the
GraphQL scalars; `'not-found' as const` is the sentinel shape.

## Directory Structure

```
server/
├── architecture.unit.test.ts   # project-wide convention tests (source of truth)
├── domain/                      # business logic (DDD bounded contexts)
│   ├── shared/                  # cross-domain types + the GraphQL plumbing
│   │   ├── types.ts             # UserId, Count
│   │   ├── primitives.ts        # their Zod constructors
│   │   └── graphql/             # builder.ts, scalars.ts, schema.ts, loaders.ts
│   └── {domain}/                # one folder per domain (recipe, proposal, …)
│       ├── types.ts             # domain types (branded)
│       ├── primitives.ts        # Zod validation constructors
│       ├── command.ts           # write operations (public namespace)
│       ├── query.ts             # read operations (public namespace)
│       ├── business-rules.ts    # (optional) pure functions, no IO
│       ├── use-case.ts          # (optional) multi-domain orchestrations
│       ├── version.ts           # (recipe) the versioning envelope
│       ├── content/             # (recipe) VersionContent union: types.ts, dish.ts, thermomix.ts
│       └── infrastructure/
│           ├── repository.ts    # Firestore access (private to the domain)
│           └── graphql/         # enums, types, inputs, queries, mutations (Pothos)
├── routes/                      # HTTP endpoints (auto-scanned by Nitro)
│   ├── graphql.ts               # GET/POST /graphql → Apollo
│   ├── admin/migrate.post.ts    # POST /admin/migrate → runs migrations
│   └── apple/notifications.post.ts # POST /apple/notifications → App Store Server Notifications
├── middleware/auth.ts           # Firebase ID token / admin token auth (H3 middleware)
├── plugins/
│   ├── 01-sentry.ts             # error reporting (Sentry, DSN from NITRO_SENTRY_DSN)
│   └── 02-graphql.ts            # boots ApolloServer once with the assembled schema
├── system/                      # infrastructure concerns + system-hosted mini-domains
│   ├── ai/                      # Gemini engine: Ai.analyzeImport + Ai.proposeNext
│   ├── apple/                   # App Store signature verification + Apple root certificates
│   ├── changelog/               # release notes (parses the changelog asset — read-only)
│   ├── portability/             # user-data export/import (orchestrates over recipe)
│   ├── config/                  # runtime config (env)
│   ├── migration/               # runner.ts, types.ts, primitives.ts, migrations/
│   ├── firebase.ts              # firebase-admin init + db()
│   └── request-cache.ts         # per-request memoization
├── utils/
│   ├── firestore.ts             # genericDataConverter / atomically / transactionally / bulkSave / deleteInBatches
│   ├── apollo.ts                # setApollo / useApollo holder
│   └── input.ts
└── test/fake-firestore.ts       # in-memory Firestore fake with read/write accounting
```

Not every domain has every file. `recipe` is the only persisted, full-stack domain; `proposal`
is ephemeral — it owns a `use-case.ts` + GraphQL slice but **no repository and no storage** (an AI
proposal is validated and applied, never saved). The read-only `changelog` aggregation has no
`command.ts`/`repository.ts`;
`portability` orchestrates through a `use-case.ts` and owns no repository. `changelog` and
`portability` are system-hosted mini-domains: they live under `server/system/` (not
`server/domain/`) but still obey the domain rules (folder shape, purity, naming, no-throw).

## Layers

### Domain Layer (`server/domain/`)

Each domain is a self-contained bounded context. The per-file responsibilities are the generic ones
([ddd-best-practices.md](./ddd-best-practices.md#the-building-blocks-and-where-they-live)); what is
specific here:

- **types.ts** — branded types via `ts-brand`. No Zod here.
- **primitives.ts** — Zod constructors; must import both `ts-brand` and `zod` (checked by the arch test).
- **command.ts** / **query.ts** — exported as a `namespace` (`RecipeCommand`, `RecipeQuery`).
  See [error handling](./error-handling.md) for the sentinel → `GraphQLError` mapping.
- **business-rules.ts** — 100% covered by `business-rules.unit.test.ts`.
- **use-case.ts** — e.g. `ProposalUseCase`; the no-repository rule is enforced by the arch test.
- **infrastructure/repository.ts** — the **only** place `db()` is used.
- **infrastructure/graphql/** — the domain's slice of the Pothos schema.

The `recipe` domain adds a **version content variant** split (a "make illegal states unrepresentable"
application). A version is a type-agnostic *versioning envelope* (`version.ts` — `number`, `basedOn`,
`change`, `origin`, `why`, `createdAt`, attempt outcome) plus a `content` **discriminated union**
under `content/` (`VersionContent = DishContent | ThermomixContent`, tagged by `kind`). The invariant
`content.kind === recipe.type` is enforced in `RecipeCommand.create`/`addVersion`. Lineage rules
(`bestRating`/`versionToOpen`/`nextVersionNumber`) live in `business-rules.ts` and never read
`content`, so adding a recipe type is one new file in `content/` — see the
[domain guide](./domain-guide.md#adding-a-recipe-type).

### Storage — native Firestore

Storage is native Firestore via `firebase-admin`, reached through `db()` from
`server/system/firebase.ts`, and used **only** inside `infrastructure/repository.ts`.

Every collection reference is wrapped with `genericDataConverter<T>()` (from
`server/utils/firestore.ts`), which gives typed reads and recursively turns Firestore
`Timestamp` values back into JS `Date`:

```ts
const recipes = () => db().collection('recipes').withConverter(genericDataConverter<Recipe>())
```

**Aggregate root + append-only satellite.** A light pointer document plus a heavy,
append-only collection keyed by a deterministic id:

- `recipes` — the aggregate root (a small pointer: `versionCount`, `updatedAt`, …); the recipe's
  state (best rating, version to open) is *derived* from its versions, not stored on it
- `recipe-versions` — one immutable doc per version, keyed `${recipeId}_${number}`

**Standalone documents.** Not every collection is an aggregate: `ai-quotas` holds one document
per cook and per calendar month, keyed `${userId}_${month}` (`quota` domain). Nothing is scanned
and nothing is purged — last month's document is simply never read again, and an absent document
reads back as both meters at zero. `entitlements` (`entitlement` domain) holds one document per
cook, keyed by `userId`, overwritten in place on every renewal; it also carries the
`appAccountToken`, the one field queried rather than keyed (the App Store notifications name a
cook only through it).

Multi-document writes are made atomic with `atomically` (a single committed `WriteBatch`); a
counter, whose new value is a function of the stored one, uses `transactionally` instead (the
AI quota, where a batch would let two calls landing together count one); import/restore use
`bulkSave` (bounded-concurrency individual sets, above the 500-op batch cap); deletes use
`deleteInBatches`. See the [domain guide](./domain-guide.md).

### Read side — no `read-model/` layer

There is **no** `read-model/` directory. Composite reads are served two ways:

1. **Read-only domains** — `changelog` (system-hosted under `server/system/`) exposes a
   `query.ts` that assembles data through other domains' public `Query` namespaces.
2. **GraphQL satellite loaders** — derived fields on `Recipe` (`versions`, `versionToOpen`,
   `bestRating`) resolve through the per-request, micro-batched `versionsByRecipe` loader in
   `server/domain/shared/graphql/loaders.ts`, so a page of recipes never triggers N+1 reads. See
   [graphql-patterns.md](./graphql-patterns.md).

Repeated reads within a single request are collapsed by the **request cache**
(`memoizedPerRequest` in `server/system/request-cache.ts`).

### GraphQL Layer — per-domain, not central

Code-first GraphQL (Apollo Server 5 + Pothos 4), exposed at the single endpoint `POST /graphql`.
There is **no** central `server/graphql/` directory: each domain owns its slice under
`infrastructure/graphql/{enums,types,inputs,queries,mutations}.ts`. The shared plumbing lives
in `server/domain/shared/graphql/`:

- **builder.ts** — the single Pothos `SchemaBuilder`; declares the `GraphQLContext`
  (`{ event, userId, loaders }`), `DefaultFieldNullability: false`, and the branded `Scalars` map.
- **scalars.ts** — registers each branded scalar; `parseValue` runs the domain's Zod
  constructor via `validatedParse`, turning a `ZodError` into a `BAD_USER_INPUT` `GraphQLError`.
- **schema.ts** — assembles the schema by **side-effect imports** in dependency order
  (`./scalars` first, then each domain's `enums/types/inputs/queries/mutations`, then AI).
  Ends with `export const schema = builder.toSchema()`.
- **loaders.ts** — the per-request satellite loaders for `RecipeType`.
- **errors.ts** — the `never`-returning `domainError` resolver helper that maps a command sentinel
  to a `GraphQLError`, deriving `extensions.code` mechanically from the sentinel
  (`'not-found'` → `NOT_FOUND`); it sits in `match().exhaustive()` arms. See
  [error-handling.md](./error-handling.md).

Satellite domains graft fields onto the aggregate root via `builder.objectField(RecipeType, …)`.
The SDL is exported to `shared/schema.graphql` (`bun run generate:graphql`) for Apollo iOS codegen.

### Route Layer (`server/routes/`)

Only two HTTP handlers exist — the app is GraphQL-first:

- `routes/graphql.ts` — `GET`/`POST /graphql`; builds a fresh per-request context
  `{ event, userId, loaders: recipeSatelliteLoaders(userId) }` and forwards to Apollo.
- `routes/admin/migrate.post.ts` — `POST /admin/migrate` (see [migrations.md](./migrations.md)).

`middleware/auth.ts` runs for every route: `/admin/*` requires the admin bearer token
(`adminToken`); everything else (including `/graphql`) requires a valid Firebase ID token and
sets `event.context.userId`.

### System Layer (`server/system/`)

Infrastructure concerns: `ai` (Gemini), `config`, `migration`, `firebase` (`db()`),
`request-cache`. It also hosts two mini-domains that follow the domain rules:
`changelog` (application release notes) and `portability` (user-data export/import).

## Cross-Domain Rules

The five isolation rules — private repositories, validation at the boundary, no storage outside
repositories, names that carry intent, no `throw` for expected outcomes — are stated in
[ddd-best-practices.md](./ddd-best-practices.md#purity-and-isolation-rules). Here they are
**executable**: `server/architecture.unit.test.ts` walks `server/` and fails `bun run test:unit`
on any violation. It also pins where Firestore may be reached (`db()` is imported by the
repositories, `utils/firestore.ts` and the migration runner — nothing else) and that each test
tier does what its suffix claims: every `.int.test.ts` drives the fake Firestore, every
`.feat.test.ts` executes the GraphQL schema.

## Data Flow

**Simple read/write (single domain):**
```
GraphQL request → /graphql → Apollo → Pothos resolver → domain Query/Command → repository → Firestore
```

**Nested field (satellite):**
```
Pothos resolver → loaders.<field>.load(id) → (micro-batched) domain Query → single getAll
```

**Orchestrated write (multi-domain):**
```
Pothos mutation → use-case → several Commands/Queries → repositories
```

## Observability

Error reporting is wired in `server/plugins/01-sentry.ts` via `@sentry/node`, with the DSN read
from `NITRO_SENTRY_DSN`. A blank or invalid DSN disables reporting, so a bad value never breaks
the Cloud Run boot health check. Only genuine server faults (status ≥ 500, or no status) are
captured — expected 4xx (401 missing user, 404, `BAD_USER_INPUT`) are business outcomes, not
incidents. The only intentional `console` call in server code is `console.info` in the migration
runner (the arch test bans only `console.log|error|warn`).
