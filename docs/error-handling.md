# Error Handling

Portable rules — nothing here names this project. Examples use a fictional `bean` domain; this
repo's wiring (the `domainError` helper, the Sentry plugin) is in
[graphql-patterns.md](graphql-patterns.md) and [architecture.md](architecture.md#observability).

## Principle

Domain outcomes are modelled as **discriminated unions**, not exceptions. Exceptions are reserved
for genuinely unexpected failures: impossible states and infrastructure faults.

This is Wlaschin's **Railway-Oriented Programming**: a command returns the entity on success, or an
explicit sentinel for each legitimate business miss, and the API layer maps every branch
exhaustively so no outcome is silently dropped.

## Sentinels are bare strings, returned directly

Don't wrap outcomes in `{ outcome: … }` envelopes. The success payload is the domain entity itself;
a miss is a bare string literal with `as const`, which lets the return type be inferred:

```ts
// Inferred: Promise<Bean | 'not-found'>
export const rename = async (userId: UserId, id: BeanId, name: BeanName) => {
  const bean = await repository.findBy(userId, id)
  if (!bean) return 'not-found' as const
  return repository.save({ ...bean, name })
}
```

Sentinels are **rare and business-oriented**: add one only when the caller must distinguish several
legitimate results. Most queries just return the data (or `'not-found'` on a single-item lookup);
void commands return `undefined | 'not-found'`.

Keeping every sentinel a **string** is what lets the success arm of the mapping be written as "not a
string". A non-string sentinel would be silently captured as success instead of forcing a new arm.

## Mapping sentinels at the API boundary

A domain error **is** the sentinel. One `never`-returning helper turns it into a transport error,
using the sentinel as the message and deriving the error code mechanically (`'not-found'` →
`NOT_FOUND`) — no per-site message strings. Each arm then reads `.with('<sentinel>', helper)`, and
the mapping is **exhaustive**: adding a sentinel to the command becomes a compile error until the
resolver handles it.

```ts
const result = await BeanCommand.rename(userId, id, name)
return match(result)
  .with('not-found', domainError)
  .with(P.not(P.string), (bean) => bean)
  .exhaustive()
```

Never a catch-all `otherwise` for terminal outcome mapping — totality is the whole point.

### Where `if` guards stay

Exhaustive matching is for **terminal outcome mapping**. Plain `if` guards remain idiomatic for
**narrowing** — unwrapping a query result mid-flow, then continuing with the narrowed value:

```ts
const bean = await BeanQuery.byId(userId, id)
if (bean === 'not-found') return 'not-found'
// bean is a Bean from here on
```

That is the same shape as a command's own guard, not an outcome map: matching would add noise
without adding totality.

## The three levels

1. **Domain** (`query.ts` / `command.ts`) — returns discriminated unions for expected outcomes and
   **never throws** (worth enforcing with an architecture test). The rule reaches beyond the domain
   folder: system services return bare-string sentinels for business-visible misses too (an AI
   engine answering "nothing found" is an outcome, not a fault); throws there stay for infra faults.
2. **API** — maps sentinels to transport errors with a stable code, and invalid input to
   `BAD_USER_INPUT` at the validation boundary.
3. **Reporting** — an error reporter captures unexpected server faults only. Expected 4xx (missing
   user, not found, bad input) are business outcomes, not incidents, and must not page anyone.

## Throw for impossible states

If data *must* exist — it was just referenced, or produced by the previous step — and it doesn't,
that is an incoherent state: **throw**. It becomes a 500 and the reporter captures it. Since the
domain's `query`/`command` files may not throw, that check belongs in a use-case or a resolver.

**Rule of thumb:** if the caller can meaningfully recover from the absence (the user deleted
something that may no longer exist), return a sentinel. If it can't, it's a bug → throw.

## Invalid input fails at the boundary

Input validation rejects at the API edge: the scalar's parse runs the domain's validation
constructor and converts a validation failure into a `BAD_USER_INPUT` error before any resolver
runs. The domain never re-validates — the brand is the proof. See
[branded-types.md](./branded-types.md).
