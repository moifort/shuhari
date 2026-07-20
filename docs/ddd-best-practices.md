# DDD / CQRS Best Practices

Portable rules — nothing here names this project. Any TypeScript backend can adopt them as is; how
this repo wires them (its stack, its tree, its domains) is in
[architecture.md](architecture.md) and [domain-guide.md](domain-guide.md).

The rules draw on two books, cited throughout: **Eric Evans**, *Domain-Driven Design* (2003), and
**Scott Wlaschin**, *Domain Modeling Made Functional* (2018). The examples use a fictional `bean`
domain.

## The building blocks and where they live

One folder per **bounded context**, self-contained, with a fixed shape:

```
domain/bean/
├── types.ts                     # branded types + domain shapes (no validation library)
├── primitives.ts                # validation constructors that brand raw values
├── command.ts                   # public write namespace
├── query.ts                     # public read namespace
├── business-rules.ts            # (optional) pure, synchronous functions
├── use-case.ts                  # (optional) multi-domain orchestration
└── infrastructure/
    ├── repository.ts            # the only storage access, private to this context
    └── graphql/                 # this context's slice of the API schema
```

| File | Evans / Wlaschin concept | Responsibility |
|------|--------------------------|----------------|
| `types.ts` | Value Objects, Entities; types as documentation | The shapes. No validation code, no IO. |
| `primitives.ts` | Making illegal states unrepresentable | One constructor per branded type: parse, then brand. If it parses, it is valid everywhere downstream. |
| `query.ts` | The public read interface | Thin pass-through to the repository. |
| `command.ts` | The public write interface; Railway-Oriented Programming | Returns the entity, or a sentinel enumerating every legitimate business outcome. |
| `business-rules.ts` | Pure domain functions | Synchronous, no IO — trivially testable. |
| `use-case.ts` | Application Service | Coordinates several contexts; owns no business logic and no storage access. |
| `infrastructure/repository.ts` | Repository | Hides persistence behind a collection-like interface. Private to the context. |

Not every context needs every file. A context that persists nothing has no repository; a read-only
one has no `command.ts`.

## Ubiquitous language — one concept, one word

One business concept = **one word**, and it is the word the feature speaks. When the functional
conversation says *"an improvement"*, the code says `improvement` at **every** layer — domain,
API schema, client, tests — so a grep for the functional word finds the whole feature. UI copy in
another language is the *translation* of that vocabulary, never a second vocabulary.

- **Never introduce a synonym at one layer** (`wish`, `suggestion`, `idea` for an improvement):
  six months later nobody knows whether two words are two concepts.
- **Renaming the concept renames it everywhere**, in the same task. Half-renamed vocabulary is
  worse than the old name.
- The reverse holds too: when two business concepts share a word, split the word, not the concept.

## Names carry the business concept, not the technical pattern

The name IS the rule or the action. Exported names in `query.ts` / `command.ts` /
`business-rules.ts` never start with `get`/`compute`/`handle`/`process`/`manage`/`perform`/`fetch`
+ a capital.

- Reads: `all`, `byId`, `versionsOf` — never `getAll`, `fetchVersions`.
- Writes: the action — `add`, `remove`, `recordAttempt` — never `handleAdd`.
- Rules: the concept — `bestRating`, `nextVersionNumber` — never `computeBestRating`.

`findAll` / `findBy` survive inside the repository: that is the repository idiom.

## Expected absence is a returned sentinel, never an exception

> **Wlaschin:** Railway-Oriented Programming — the return type enumerates the legitimate outcomes.

A command or query returns the entity, or a **bare string sentinel** (`'not-found' as const`,
`'content-type-mismatch' as const`). `throw` is reserved for impossible states, and lives outside
`query.ts` / `command.ts`. The API layer maps each sentinel to its transport error exhaustively, so
a new sentinel is a compile error rather than a silent fall-through.

```ts
export namespace BeanQuery {
  export const byId = async (userId: UserId, id: BeanId) => {
    const bean = await repository.findBy(userId, id)
    if (!bean) return 'not-found' as const
    return bean
  }
}
```

## Purity and isolation rules

These are the four that keep the architecture honest — worth enforcing with a test that walks the
source tree, so a violation fails the build:

1. **Repositories are private.** A context may import only its *own* `infrastructure/repository`.
   Every other context is reached through the public `Query` / `Command` namespaces.
2. **No storage outside repositories.** `use-case.ts` and `business-rules.ts` never touch the
   database; `business-rules.ts` is not even `async`.
3. **Validation happens once, at the boundary.** Data entering the domain is validated and branded
   at the API edge (Evans's Anti-Corruption Layer). Nothing re-validates internally.
4. **No `throw` for expected outcomes** in `query.ts` / `command.ts`.

## Business rules are pure and fully covered

Extract the reasoning of a complex command into `business-rules.ts`: pure, synchronous functions
whose names are the business concept. They take domain shapes and return domain shapes — no IO, no
`async`, no clock. That makes 100% test coverage cheap, so require it.

## Use cases orchestrate, they don't decide

A `use-case.ts` exists when one entry point must coordinate several contexts. It calls public
`Command` / `Query` namespaces only, never a repository, and holds no business logic of its own —
if a decision appears there, it belongs in a domain's `business-rules.ts`. Its names carry intent
(`fromAttempt`, `accept`), never `handleX` / `processX`.

Keep the dependency direction one-way: if `proposal` orchestrates over `recipe`, `recipe` must
never import `proposal`.

## Read side — derive, don't duplicate

Prefer deriving composite reads over maintaining a parallel read model:

- **Read-only contexts** assemble data through other contexts' public `Query` namespaces.
- **Nested API fields** resolve through per-request, micro-batched loaders — one batched read per
  field per request, and nothing at all when the field is not selected. See
  [graphql-best-practices.md](graphql-best-practices.md).
- **Repeated reads inside one request** collapse through a request-scoped memoization helper.

A field that is *derived* (a best score, the version to open) is computed by a business rule at read
time, not stored and kept in sync. A stored duplicate is a bug waiting for the day the two disagree.

## Storage patterns

Whatever the document store, three patterns carry most of the weight:

- **A typed converter on every collection reference**, so reads come back as domain shapes and
  stored timestamps become real `Date`s.
- **Aggregate root + append-only satellite**: a small pointer document per aggregate, plus a heavy
  collection of immutable rows keyed deterministically (`${aggregateId}_${n}`). The aggregate's
  derived state is computed from the satellite, not written onto the root.
- **Atomic multi-document writes**: a handful of writes enlist into one batch committed once
  (all-or-nothing). Bulk import/restore, which exceeds a batch's operation cap, uses
  bounded-concurrency individual writes instead.

Every query is scoped by the owner's id — multi-tenancy is not a filter the caller can forget.

## Migrations are forward-only and owned by a runner

Changing the *shape* of stored data is a migration; adding to it usually isn't.

- **Migrate** when a field is renamed, restructured, or removed, or when an enum value changes
  meaning.
- **Don't migrate** when adding an optional field, a new collection, or changing query logic.

Four rules keep them boring: sequential and **forward-only** (no rollback path to test and never
use); the **runner** owns error handling and the applied-version bookkeeping, so each migration is
just a transform; each migration gets an integration test that seeds the old shape and asserts the
new one; and they run through a controlled, authenticated entry point during deploy — never by hand
against production.

## Tests state the budget, not just the behaviour

Integration tests run against an in-memory fake of the store that records reads, writes and
batches. Assert three things:

- **Behaviour** — what was persisted.
- **Atomicity** — no direct writes escaped the batch (`directWrites` empty, one batch committed).
- **Read budget** — the exact number of reads a call costs, and that a second identical read within
  the request costs zero. Without this assertion, an N+1 slips in the day someone adds a field.
