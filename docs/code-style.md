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
the returned entity, so `addVersion` infers `Promise<Recipe | 'not-found'>` on its own.

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

**Items are never optional either** — an array is *total*: neither the list nor any of its slots can
be absent. A parallel array aligned by index (`tmxSteps` mirrors `steps`) must not spell "nothing
here" as a hole; give the element type a neutral value instead.

```ts
// Bad — two spellings of "no setting", and a hole Firestore can't store
tmxSteps: (TmxSettings | undefined)[]
// Good — every field of TmxSettings is optional, so `{}` IS "plain step"
tmxSteps: TmxSettings[]
```

At the GraphQL boundary this means **`[T!]!` everywhere**, in output types *and* inputs/args —
never `[T]`, `[T]!` or `[T!]`. A client sends `[]` for "none", never `null`, and an empty element
for "this slot carries nothing".

Applies to both backend TypeScript and iOS Swift (`[TmxSettings]`, never `[TmxSettings?]` nor
`[TmxSettings]?`). When absence seems meaningful, derive it from a real field instead of the array's
presence — a Thermomix recipe is `type === 'tmx'`, not "`tmxSteps` is present" (see the next rule).

### ⛔ No `null` in the domain — absence is `?` / `undefined`

> **Wlaschin:** one representation per state. `null` and `undefined` are two spellings of "absent";
> keeping both makes every guard a coin flip (`=== null`? `== null`? `?? `?).

The domain (`types.ts`, `primitives.ts`, `command.ts`, `query.ts`, `business-rules.ts`,
`use-case.ts`, `infrastructure/repository.ts`, `server/system/**`, `server/utils/**`) never spells
absence `null`: an absent field is `field?: T` (and the key is simply **not written**), a lookup that
finds nothing returns `T | undefined` — or the discriminated `'not-found' as const` sentinel where
the flow already uses one.

```ts
// Bad
type RecipeVersion = { basedOn: VersionNumber | null; rating: Rating | null }
export const bestRating = (versions: RecipeVersion[]): RecipeVersion | null => …
// Good
type RecipeVersion = { basedOn?: VersionNumber; rating?: Rating }
export const bestRating = (versions: RecipeVersion[]): RecipeVersion | undefined => …
```

`null` survives only at the **boundaries**, where a protocol imposes it, and it is converted on the
spot:

| Boundary | Direction | Conversion |
| --- | --- | --- |
| GraphQL (`infrastructure/graphql/*.ts`) | out | `nullable: true` + `resolve: (v) => v.x ?? null` |
| GraphQL inputs | in | `stripNulls` (`server/utils/input.ts`) drops the null keys |
| Firestore (`infrastructure/repository.ts`) | both | `withoutAbsentFields` on write, `withoutStoredNulls` on read (`server/utils/firestore.ts`) |
| Gemini JSON (`system/ai/primitives.ts`) | in | `nullAsAbsent` / Zod `.nullish()` transforms |

Two Firestore consequences to keep in mind: a write must be a full `set` for a dropped key to
**erase** the stored field (an omitted key in an `update`/`merge` leaves the old value untouched),
and an array element cannot be absent — a positional hole (a plain step in `tmxSteps`) is encoded as
a stored `null` and decoded back to `undefined` on read.

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
`byId`, `versionsOf`; writes as the action (`create`, `addVersion`, `recordAttempt`); rules as
the concept (`bestRating`, `versionToOpen`, `nextVersionNumber`). `findAll`/`findBy` stay — that is
the repository idiom.

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
`errors.ts` `domainError` helper, whose `never` return type sits in a `match` arm while the success
arm keeps the resolver's inferred type. The helper **is** the sentinel — it throws the sentinel as
the message and derives its `extensions.code` mechanically — so each arm is just
`.with('<sentinel>', domainError)`:

```ts
import { match, P } from 'ts-pattern'
import { domainError } from '~/domain/shared/graphql/errors'

match(result)
  .with('not-found', domainError)
  .with('no-recipe-found', domainError)
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

All code, comments, commit messages, and documentation are in **English** — including `CHANGELOG.md`,
the source of truth. The only French in the repo is user-facing copy (`CHANGELOG.fr.md`, the copy
served to the app, and the iOS app's on-screen text).

### The whole backend is English

Identifiers, folder and file names, comments, GraphQL descriptions, AI prompts, test names: not one
French word. A reader of `server/` should never need to know French to read the model.

```ts
// Bad
export const noterEssai = async (userId: UserId, input: EssaiInput) => …
// Good
export const recordAttempt = async (userId: UserId, input: RecordAttemptInput) => …
```

### Enum values, unions and discriminants are English technical symbols

> **Evans:** Ubiquitous Language — but the language of the *domain model*, not of the *reader*.
> A schema value is an identity, not a label; the moment it doubles as a label it can never be
> translated, renamed or reused.

Enum members (`DISH`, `STARTER`, `AI_PROPOSAL`), their backing values (`dish`, `starter`,
`ai-proposal`) and every discriminant (`origin.kind`, `'not-found'`) are English symbols. The
front-end owns the wording: `RecipeType.DISH` travels over the wire, and
`ios/Shuhari/Shared/RecipeType.swift` maps `.dish` to the on-screen label "Plat". The schema never
speaks the user's language.

```ts
// Bad — the label leaks into the schema; the day the app speaks English, the data is wrong
export const RECIPE_TYPE_VALUES = ['plat', 'tmx'] as const
// Good — a symbol the app translates
export const RECIPE_TYPE_VALUES = ['dish', 'tmx'] as const
```

### Same rule on iOS — French is display copy only

Identifiers, file names, comments and accessibility **identifiers** (`"home-settings-button"`) are
English. French is reserved for the copy the user actually reads: `Text`, `label`,
`navigationTitle`, `accessibilityLabel`, and Xcode preview names (`#Preview("Plat")`) — the previews
are a developer-facing gallery of the French UI, so they are named in the UI's language.

```swift
// Bad
button.accessibilityIdentifier = "bouton-reglages"
// Good — English identifier, French label
Button("Historique") { … }.accessibilityIdentifier("recipe-history-button")
```

### The deliberate exceptions

Everything below is French **on purpose** — nothing else is:

- `CHANGELOG.fr.md` (the copy served to the app) and its generated asset
  `server/system/changelog-content.ts`.
- French **data values** quoted as examples in code, comments, GraphQL descriptions and AI prompts:
  the Thermomix speed vocabulary (`"mijotage"`, `"Varoma"`, the accented kneading speed),
  ingredient names (`"Pommes de terre"`), quantities. The AI must produce them verbatim — they are
  user data, not vocabulary of the model.
- The French fallback title used when an import yields no title
  (`server/system/ai/primitives.ts`, `raw.title || …`) — user-visible copy the server produces.
- Test fixtures that simulate user data (recipe titles, ingredient names, step text).

The control is a grep for accented letters (the Latin-1 range, so the command itself stays ASCII),
which must return only the above:

```bash
grep -rnP '[\x{00C0}-\x{00FF}]' server/
```

It is a smoke test, not a proof: `plat`, `essai` or `note` carry no accent — read the names too.

## Swift Rules

See [ios-guide.md](./ios-guide.md) for the full iOS conventions. In short:

- `@MainActor @Observable` on ViewModels (`*Store` / `*ViewModel`) — the Observation framework,
  not `ObservableObject`.
- Model types are `Sendable` (Swift 6 strict concurrency).
- Leaf views take **primitives**, never domain structs.
- Arrays are never optional (same rule as TypeScript).
- Write accented French copy as actual UTF-8 characters, never as `"\u{00E9}"`-style escapes.
- Every component below page level is previewable (`#Preview`).
