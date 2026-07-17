# Backend Architecture

## Overview

The backend follows a strict Domain-Driven Design (DDD) / CQRS architecture built on
[Nitro](https://nitro.build/) (preset `firebase`, Firebase Cloud Functions Gen 2), with
TypeScript, **native Firestore** storage (`firebase-admin`), branded types, and a single
GraphQL endpoint (Apollo Server + Pothos).

## Theoretical Foundations

This architecture draws from two foundational DDD books:

- **Eric Evans** — *Domain-Driven Design: Tackling Complexity in the Heart of Software* (2003)
- **Scott Wlaschin** — *Domain Modeling Made Functional* (2018)

**Evans concepts used in this project:**

| Concept | Where |
|---------|-------|
| Bounded Context | Each `server/domain/{domain}/` is a self-contained context with clear boundaries |
| Ubiquitous Language | Function and type names carry business meaning, not technical jargon |
| Value Objects | Branded types in `types.ts` — identity through value, not reference |
| Entities | Domain types with an `id` (`Recipe`, `Trial`) in `types.ts` |
| Repository | `infrastructure/repository.ts` — abstracts Firestore, private to the bounded context |
| Application Services | `query.ts`, `command.ts`, `use-case.ts` — orchestrate domain operations |
| Anti-Corruption Layer | Zod validation at the GraphQL boundary (scalars) prevents invalid data from entering |

**Wlaschin concepts used in this project:**

| Concept | Where |
|---------|-------|
| Making illegal states unrepresentable | Branded types + Zod constructors in `primitives.ts` |
| Railway-Oriented Programming | Discriminated-union returns in commands (the entity, or a string sentinel like `'not-found'`) — reserved for expected business outcomes only. `throw` for impossible states. |
| Types as documentation | Branded types make the domain model self-documenting |
| Pure domain functions | `business-rules.ts` — no IO, no `async`, pure input/output |

Many of these rules are **enforced by `server/architecture.unit.test.ts`** — that file is
the executable source of truth. See the [code style guide](./code-style.md).

## Directory Structure

```
server/
├── architecture.unit.test.ts   # project-wide convention tests (source of truth)
├── domain/                      # business logic (DDD bounded contexts)
│   ├── shared/                  # cross-domain types + the GraphQL plumbing
│   │   ├── types.ts             # UserId, Count
│   │   ├── primitives.ts        # their Zod constructors
│   │   └── graphql/             # builder.ts, scalars.ts, schema.ts, loaders.ts
│   └── {domain}/                # one folder per domain (recipe, trial, proposal, …)
│       ├── types.ts             # domain types (branded)
│       ├── primitives.ts        # Zod validation constructors
│       ├── command.ts           # write operations (public namespace)
│       ├── query.ts             # read operations (public namespace)
│       ├── business-rules.ts    # (optional) pure functions, no IO
│       ├── use-case.ts          # (optional) multi-domain orchestrations
│       └── infrastructure/
│           ├── repository.ts    # Firestore access (private to the domain)
│           └── graphql/         # enums, types, inputs, queries, mutations (Pothos)
├── routes/                      # HTTP endpoints (auto-scanned by Nitro)
│   ├── graphql.ts               # GET/POST /graphql → Apollo
│   └── admin/migrate.post.ts    # POST /admin/migrate → runs migrations
├── middleware/auth.ts           # Firebase ID token / admin token auth (H3 middleware)
├── plugins/
│   ├── 01-sentry.ts             # error reporting (Sentry, DSN from NITRO_SENTRY_DSN)
│   └── 02-graphql.ts            # boots ApolloServer once with the assembled schema
├── system/                      # infrastructure concerns
│   ├── ai/                      # Gemini import + proposal engine
│   ├── config/                  # runtime config (env)
│   ├── migration/               # runner.ts, types.ts, primitives.ts, migrations/
│   ├── firebase.ts              # firebase-admin init + db()
│   └── request-cache.ts         # per-request memoization
├── utils/
│   ├── firestore.ts             # genericDataConverter / atomically / bulkSave / deleteInBatches
│   ├── apollo.ts                # setApollo / useApollo holder
│   └── input.ts
└── test/fake-firestore.ts       # in-memory Firestore fake with read/write accounting
```

Not every domain has every file. The full-stack domains are `recipe`, `trial`, `proposal`.
Read-only aggregations (`home`, `changelog`) have no `command.ts`/`repository.ts`;
`portability` orchestrates through a `use-case.ts` and owns no repository.

## Layers

### Domain Layer (`server/domain/`)

Each domain is a self-contained bounded context:

- **types.ts** — Branded types via `ts-brand`, plus plain domain shapes. No Zod here.
  Evans: Value Objects and Entities.
- **primitives.ts** — Zod constructors that validate and brand raw values. Wlaschin: making
  illegal states unrepresentable — if it parses, it is valid. Must import both `ts-brand`
  and `zod` (checked by the arch test).
- **command.ts** — Public write operations, exported as a `namespace` (e.g. `RecipeCommand`).
  Returns the entity or a **string sentinel** (`'not-found'`, `'nothing-to-test'`). See
  [error handling](./error-handling.md).
- **query.ts** — Public read operations (e.g. `RecipeQuery`). Thin pass-through to the
  repository; single-item lookups return `'not-found' as const` on absence.
- **business-rules.ts** — (optional) Pure, **synchronous** functions. Names ARE the business
  concept (`readyToPromote`, `nextVersionNumber`, `applyProposalToParams` — never `computeX`).
  100% test coverage (`business-rules.unit.test.ts`).
- **use-case.ts** — (optional) Multi-domain orchestration. Goes through commands/queries
  only — **may not import any repository or touch storage** (enforced). Names carry intent
  (`removeCompletely`, never `handleX`).
- **infrastructure/repository.ts** — The **only** place `db()` is used. Private to the domain.
- **infrastructure/graphql/** — The domain's slice of the Pothos schema.

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

- `recipes` — the aggregate root (a small pointer: `currentVersion`, `toTest`, `versionCount`, …)
- `recipe-versions` — one immutable doc per version, keyed `${recipeId}_${number}`

Multi-document writes are made atomic with `atomically` (a single committed `WriteBatch`);
import/restore use `bulkSave` (bounded-concurrency individual sets, above the 500-op batch
cap); deletes use `deleteInBatches`. See the [domain guide](./domain-guide.md).

### Read side — no `read-model/` layer

There is **no** `read-model/` directory. Composite reads are served two ways:

1. **Read-only domains** — `home` (the dashboard aggregation) and `changelog` expose a
   `query.ts` that assembles data through other domains' public `Query` namespaces.
2. **GraphQL satellite loaders** — nested fields on `Recipe`/`Version` (`currentVersion`,
   `trials`, `pendingProposal`, `variations`, …) resolve through per-request, micro-batched
   loaders in `server/domain/shared/graphql/loaders.ts`, so a page of recipes never triggers
   N+1 reads. See [graphql-patterns.md](./graphql-patterns.md).

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
`request-cache`.

## Cross-Domain Rules (enforced by `architecture.unit.test.ts`)

1. **Repositories are private** — a domain may import only its *own*
   `infrastructure/repository`. The test fails on any cross-domain repository import. Other
   domains go through the public `Query`/`Command` namespaces.
2. **Validation at the boundary** — data entering the domain is validated/branded once, at the
   GraphQL scalar boundary. No re-validation internally. Evans: Anti-Corruption Layer.
3. **No storage outside repositories** — `use-case.ts` and `business-rules.ts` may not touch
   storage; `business-rules.ts` may not even be `async`.
4. **Names carry intent** — exported `query`/`command`/`business-rules` names may not start with
   `get`/`compute`/`handle`/`process`/`manage`/`perform`/`fetch` + a capital. `findAll`/`findBy`
   stay (repository idiom).
5. **No `throw new Error` in `query.ts`/`command.ts`** — expected absence is a returned sentinel.

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
