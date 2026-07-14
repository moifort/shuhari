# Error Handling

## Principle

Domain-level outcomes are modelled as **discriminated unions**, not exceptions. Exceptions are
reserved for truly unexpected failures (impossible states, infrastructure errors).

This implements Wlaschin's **Railway-Oriented Programming**: a command returns the entity on
success or an explicit sentinel for each legitimate business miss. The GraphQL resolver maps
every branch — ideally with `match().exhaustive()`, so no outcome is silently dropped.

## Sentinels are bare strings, returned directly

Shuhari does **not** wrap outcomes in `{ outcome: … }` objects. The success payload is the
domain entity itself; a miss is a bare string literal with `as const`:

```ts
export const promote = async (
  userId: UserId,
  recipeId: RecipeId,
  versionNumber: VersionNumber,
): Promise<Recipe | 'not-found' | 'nothing-to-test'> => {
  const recipe = await repository.findBy(userId, recipeId)
  if (!recipe) return 'not-found' as const
  if (recipe.toTest !== versionNumber) return 'nothing-to-test' as const
  const updated: Recipe = { ...recipe, currentVersion: versionNumber, toTest: null, updatedAt: new Date() }
  return repository.save(updated)
}
```

Sentinels are **rare and business-oriented** — use one only when the caller must distinguish
multiple legitimate results. Most queries just return the data (or `'not-found'` on a single-item
lookup). Void commands return `undefined | 'not-found'`.

## Mapping Sentinels in GraphQL

The resolver translates each sentinel into a `GraphQLError` with a stable `extensions.code`.

### Target style — `match().exhaustive()`

```ts
import { match } from 'ts-pattern'
import { GraphQLError } from 'graphql'

const notFound = () => new GraphQLError('Recipe not found', { extensions: { code: 'NOT_FOUND' } })

const result = await RecipeCommand.promote(userId, recipeId, versionNumber)
return match(result)
  .with('not-found', () => { throw notFound() })
  .with('nothing-to-test', () => {
    throw new GraphQLError('No version awaiting a trial', { extensions: { code: 'NOTHING_TO_TEST' } })
  })
  .otherwise((recipe) => recipe)
```

`match().exhaustive()` gives totality: adding a fourth sentinel to the command turns this into a
compile error until the resolver handles it.

### Where `if` guards stay

`ts-pattern` is a project dependency and `match` is the standard for **terminal outcome mapping**
in resolvers. `if` guards remain idiomatic for **narrowing** — unwrapping a query result mid-flow
inside a use-case, then continuing with the narrowed value:

```ts
const recipe = await RecipeQuery.byId(userId, recipeId)
if (recipe === 'not-found') return 'not-found'
// recipe is now Recipe — keep going
```

This is the same shape as a command's own guard (`if (!recipe) return 'not-found' as const`), not
an outcome map, so `match` would add noise without adding totality.

## Error-handling levels

1. **Domain layer** (`query.ts` / `command.ts`) — returns discriminated unions for expected
   outcomes; **⛔ never `throw new Error`** (enforced by the arch test). Throws only for truly
   impossible states, and that logic lives outside these two files.
2. **GraphQL layer** — maps sentinels to `GraphQLError` + `extensions.code`; maps invalid input
   to `BAD_USER_INPUT` at the scalar boundary.
3. **Plugin layer** — `plugins/01-sentry.ts` reports unexpected server faults (via `NITRO_SENTRY_DSN`).

## Throw for impossible states

If data *must* exist (just referenced, produced by a prior step) and doesn't, that is an
incoherent state — **throw**, don't return a sentinel. The framework turns it into a 500 and
Sentry captures it. Because the domain `query`/`command` files may not `throw`, put this check in
a `use-case.ts` or a resolver.

**Rule of thumb:** if the caller can meaningfully recover from the absence (the user deleted
something that may not exist), return a sentinel. If it can't, it's a bug → throw.

## Zod validation errors → `BAD_USER_INPUT`

Invalid input is rejected at the GraphQL scalar boundary. Each branded scalar's `parseValue`
runs its Zod constructor through `validatedParse`, which converts a `ZodError` into:

```ts
throw new GraphQLError(`Invalid value for ${name}: ${message}`, {
  extensions: { code: 'BAD_USER_INPUT' },
})
```

The domain never re-validates — branded types guarantee validity downstream. See
[branded-types.md](./branded-types.md) and [graphql-patterns.md](./graphql-patterns.md).
