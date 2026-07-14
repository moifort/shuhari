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

Runtime is always `bun`/`bunx`, never `npm`/`npx`.

## TypeScript Rules

### Never type return values

Let TypeScript infer — the annotation duplicates what the body already proves, and drifts from it.
This includes command outcomes: the discriminated union follows from the `as const` sentinels and
the returned entity, so `promote` infers `Promise<Recipe | 'not-found' | 'nothing-to-test'>` on its
own.

```ts
// Bad
export const all = async (userId: UserId): Promise<Recipe[]> => repository.findAllByUser(userId)

// Good
export const all = async (userId: UserId) => repository.findAllByUser(userId)
```

### `as const` on literal sentinel returns

Required for the union to narrow. Sentinels are **bare strings**, not objects:

```ts
if (!recipe) return 'not-found' as const
```

### Full variable names

> **Evans:** Ubiquitous Language — code reads like the domain. `recipe` says what it is; `r` says nothing.

```ts
// Bad
versions.filter((v) => v.number > current)
// Good
versions.filter((version) => version.number > current)
```

### Destructure in callbacks

```ts
// Bad
sortBy(versions, (v) => v.number)
// Good
sortBy(versions, ({ number }) => number)
```

### Inline single-line guards

```ts
// Bad
if (!recipe) {
  return 'not-found' as const
}
// Good
if (!recipe) return 'not-found' as const
```

### Use `Date`, not `string`, for timestamps

```ts
type Recipe = { createdAt: Date; updatedAt: Date }
```

The Firestore converter (`genericDataConverter`) restores `Timestamp` → `Date` on read.

### Arrays never optional

> **Wlaschin:** make illegal states unrepresentable — `[]` is a valid array. An optional array
> creates two representations of "empty" (`undefined` vs `[]`), an illegal state.

```ts
// Bad
type RecipeVersion = { ingredients?: Ingredient[] }
// Good
type RecipeVersion = { ingredients: Ingredient[] }  // [] is the neutral state
```

Applies to both backend TypeScript and iOS Swift. When absence seems meaningful, derive it from a
real field instead of the array's presence — a Thermomix recipe is `type === 'tmx'`, not "`tmxSteps`
is present" (see the next rule).

### No boolean derivable from another field

Never store a boolean whose truth is already implied by another field (`toTest !== null` implies "has
a pending version"; `type === 'tmx'` implies "is Thermomix"). Derive it in a pure function or a
resolver instead.

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
`byId`, `versionsOf`; writes as the action (`importRecipe`, `promote`, `deriveVariation`); rules as
the concept (`readyToPromote`, `nextVersionNumber`). `findAll`/`findBy` stay — that is the
repository idiom.

### ⛔ `business-rules.ts` is pure — no `async`, no storage

Pure, synchronous functions only. No `useStorage`, no `async`, no `db()`.

### ⛔ No cross-domain repository imports

A domain may import only its own `infrastructure/repository`. Reach other domains through their
public `Query`/`Command` namespaces.

### Never `switch` — use `match().exhaustive()`

> **Wlaschin:** totality — `.exhaustive()` forces every case; a new sentinel becomes a compile
> error, not a silent fall-through.

`ts-pattern` is a project dependency (`ts-pattern@5.9.0`). Map a command's sentinels in the
resolver, terminating with `.exhaustive()` (never `.otherwise()`); throw through the shared
`errors.ts` helpers, whose `never` return type sits in a `match` arm while the success arm keeps the
resolver's inferred type:

```ts
import { match, P } from 'ts-pattern'
import { domainError, notFound } from '~/domain/shared/graphql/errors'

match(result)
  .with('not-found', () => notFound('Recipe not found'))
  .with('nothing-to-test', () => domainError('NOTHING_TO_TEST', 'No version awaiting a trial'))
  .with(P.not(P.string), (recipe) => recipe)
  .exhaustive()
```

### Use `lodash-es`

Utilities come from `lodash-es` (tree-shakeable). The codebase uses `chunk`, `sortBy`, etc.

```ts
import { chunk, sortBy } from 'lodash-es'
```

### Never `for`/`while` loops — use functional style

> **Wlaschin:** functional composition — `map`/`filter`/`reduce` express intent declaratively.

```ts
// Bad
for (const change of changes) { ... }
// Good
changes.reduce((params, change) => ..., params)
```

The one pragmatic exception is a bounded loop over Firestore batch chunks (writing under the 500-op
cap is inherently sequential) and the per-request loader dispatch — see `utils/firestore.ts` and
`shared/graphql/loaders.ts`.

### Error handling at the caller level

Don't wrap each unit in try/catch; let the orchestrator handle failure once (e.g. the migration
runner wraps each migration). See [error-handling.md](./error-handling.md).

### `console`

⛔ No `console.log`/`console.error`/`console.warn` in server code. `console.info` is tolerated for
the one deliberate site (the migration runner) — error reporting otherwise goes through Sentry
(`plugins/01-sentry.ts`).

## Language

All code, comments, commit messages, and documentation are in **English**. The only French in the
repo is user-facing copy (`CHANGELOG.md` and the iOS app's on-screen text).

## Swift Rules

See [ios-guide.md](./ios-guide.md) for the full iOS conventions. In short:

- `@MainActor @Observable` on ViewModels (`*Store` / `*ViewModel`) — the Observation framework,
  not `ObservableObject`.
- Model types are `Sendable` (Swift 6 strict concurrency).
- Leaf views take **primitives**, never domain structs.
- Arrays are never optional (same rule as TypeScript).
- Write actual UTF-8 characters in strings (`"Série"`, not `"S\u{00E9}rie"`).
- Every component below page level is previewable (`#Preview`).
