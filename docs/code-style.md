# Code Style Guide

Some rules here are **enforced** by `server/architecture.unit.test.ts` (marked ⛔ — a violation
fails `bun test`); the rest are **conventions** the codebase follows by preference. Many implement
DDD principles from Evans (*Domain-Driven Design*) and Wlaschin (*Domain Modeling Made Functional*).

## Formatter — Biome

- Spaces (width 2), single quotes, **no semicolons**
- Line width: 100

```bash
bun run lint        # bunx biome check
bun run lint:fix    # autofix
```

## TypeScript Rules

### Annotate command outcomes; let thin reads infer

Commands make their outcomes explicit by annotating the discriminated-union return type — this
is how the sentinel contract is documented:

```ts
export const promote = async (
  userId: UserId,
  recipeId: RecipeId,
  versionNumber: VersionNumber,
): Promise<Recipe | 'not-found' | 'nothing-to-test'> => { … }
```

Thin pass-through reads let TypeScript infer:

```ts
export const all = async (userId: UserId) => repository.findAllByUser(userId)
```

### `as const` on literal sentinel returns

Required for the union to narrow. Sentinels are **bare strings**, not objects:

```ts
if (!recipe) return 'not-found' as const
```

### Use `Date`, not `string`, for timestamps

```ts
type Recipe = { createdAt: Date; updatedAt: Date }
```

The Firestore converter (`genericDataConverter`) restores `Timestamp` → `Date` on read.

### Prefer `[]` as the neutral state over optional arrays

An always-present array has one representation of "empty". Reserve an **optional** array for
when absence is semantically distinct from empty (e.g. `RecipeVersion.tmxSteps?` — absent means
"not a Thermomix recipe / legacy version", which is not the same as "no steps").

```ts
changedKeys: ParamKey[]          // [] is the neutral state
tmxSteps?: (TmxSettings | null)[] // optional: absence carries meaning
```

### ⛔ Never `as SomeBrand` on raw input — go through the Zod constructor

```ts
// Bad
const id = body.id as RecipeId
// Good
const id = RecipeId(body.id)
```

(Casting an already-Zod-validated value to its union type, as enum primitives do, is fine.)

### ⛔ No `throw new Error` in domain `query.ts` / `command.ts`

Expected absence is a returned sentinel, not an exception. `throw` is reserved for impossible
states, and lives outside these two files. See [error-handling.md](./error-handling.md).

### ⛔ Names carry the business concept, not the technical pattern

Exported names in `query.ts` / `command.ts` / `business-rules.ts` may not start with
`get`/`compute`/`handle`/`process`/`manage`/`perform`/`fetch` + a capital. Reads read as `all`,
`byId`, `versionsOf`; writes as the action (`importRecipe`, `promote`, `deriveVariation`);
rules as the concept (`readyToPromote`, `nextVersionNumber`). `findAll`/`findBy` stay — that is
the repository idiom.

### ⛔ `business-rules.ts` is pure — no `async`, no storage

Pure, synchronous functions only. No `useStorage`, no `async`, no `db()`.

### ⛔ No cross-domain repository imports

A domain may import only its own `infrastructure/repository`. Reach other domains through their
public `Query`/`Command` namespaces.

### Use `match().exhaustive()` over `switch` (adopted target style)

Map a command's sentinels with `ts-pattern`'s `match(...).exhaustive()` — adding a new sentinel
becomes a compile error instead of a silent fall-through:

```ts
import { match } from 'ts-pattern'

match(result)
  .with('not-found', () => { throw notFound() })
  .with('nothing-to-test', () => { throw new GraphQLError('…', { extensions: { code: 'NOTHING_TO_TEST' } }) })
  .otherwise((recipe) => recipe)
```

> `ts-pattern` is the adopted convention but **not yet a dependency** — current resolvers use
> explicit `if (result === 'not-found')` guards. Add the package before using `match`, and
> migrate guards as you touch them.

### Use `lodash-es`

Utilities come from `lodash-es` (tree-shakeable). The codebase uses `chunk`, `sortBy`, etc.

```ts
import { chunk, sortBy } from 'lodash-es'
```

### Loops are allowed

Imperative `for…of` / `while` are used freely where they read best (batching, in-place merges) —
see `utils/firestore.ts`, `shared/graphql/loaders.ts`, `recipe/business-rules.ts`. Use `map`/
`filter`/`reduce` when they are clearer; there is no ban on loops.

### `console`

⛔ No `console.log`/`console.error`/`console.warn` in server code. `console.info` is tolerated
for the one deliberate site (the migration runner) — error reporting otherwise goes through fixme
(`plugins/01-fixme.ts`).

## Swift Rules

See [ios-guide.md](./ios-guide.md) for the full iOS conventions. In short:

- `@MainActor @Observable` on ViewModels (`*Store` / `*ViewModel`) — the Observation framework,
  not `ObservableObject`.
- Model types are `Sendable` (Swift 6 strict concurrency).
- Leaf views take **primitives**, never domain structs.
- Every component below page level is previewable (`#Preview`).
