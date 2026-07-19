# Adding a New Domain

Step-by-step guide to adding a backend domain. Each step maps to a DDD building block from
Evans (*Domain-Driven Design*) or Wlaschin (*Domain Modeling Made Functional*). The examples
come from the real `recipe` (persisted) and `proposal` (ephemeral) domains.

> The rules below are enforced by `server/architecture.unit.test.ts` — run `bun test` and it
> will fail if a new domain breaks a convention.

## 1. Create the Domain Directory

```
server/domain/bean/
├── types.ts
├── primitives.ts
├── command.ts
├── query.ts
└── infrastructure/
    ├── repository.ts
    └── graphql/
        ├── enums.ts
        ├── types.ts
        ├── inputs.ts
        ├── queries.ts
        └── mutations.ts
```

`business-rules.ts` and `use-case.ts` are optional (see the end of this guide).

## 2. Define Types (`types.ts`)

> **Evans:** Value Objects and Entities. **Wlaschin:** types as documentation.

Branded types via `ts-brand`, plus plain domain shapes. **No Zod here.**

```ts
import type { Brand } from 'ts-brand'
import type { UserId } from '~/domain/shared/types'

export const ROAST_VALUES = ['light', 'medium', 'dark'] as const
export type Roast = (typeof ROAST_VALUES)[number]

export type BeanId = Brand<string, 'BeanId'>
export type BeanName = Brand<string, 'BeanName'>

export type Bean = {
  id: BeanId
  userId: UserId
  name: BeanName
  roast: Roast
  createdAt: Date
}
```

Arrays are never optional — `[]` is the neutral state. Use `Date`, never `string`, for dates.

## 3. Create Primitives (`primitives.ts`)

> **Wlaschin:** making illegal states unrepresentable — if a value passes the constructor, it
> is valid everywhere downstream. Must import `ts-brand` and `zod` (checked by the arch test).

One factory per brand: `zod` parse → `ts-brand` `make`. Enum brands parse and cast (no `make`).

```ts
import { make } from 'ts-brand'
import { z } from 'zod'
import { type BeanId as BeanIdType, type BeanName as BeanNameType, ROAST_VALUES,
  type Roast as RoastType } from '~/domain/bean/types'

export const BeanId = (value: unknown) => {
  const v = z.string().uuid().parse(value)
  return make<BeanIdType>()(v)
}
export const randomBeanId = () => BeanId(crypto.randomUUID())

export const BeanName = (value: unknown) => {
  const v = z.string().trim().min(1).max(200).parse(value)
  return make<BeanNameType>()(v)
}

export const Roast = (value: unknown) => z.enum(ROAST_VALUES).parse(value) as RoastType
```

See [branded-types.md](./branded-types.md) for the full pattern (string coercion, etc.).

## 4. Create the Repository (`infrastructure/repository.ts`)

> **Evans:** Repository — a collection-like interface that hides persistence. Private to the
> bounded context (no other domain may import it — enforced).

This is the **only** file allowed to use `db()`. Wrap every collection with
`genericDataConverter<T>()`. Scope every query by `userId`. Accept an optional `WriteBatch` so
callers can enlist the write in an atomic commit. Memoize full scans with `memoizedPerRequest`.

```ts
import type { WriteBatch } from 'firebase-admin/firestore'
import type { Bean, BeanId } from '~/domain/bean/types'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import { memoizedPerRequest } from '~/system/request-cache'
import { genericDataConverter } from '~/utils/firestore'

const beans = () => db().collection('beans').withConverter(genericDataConverter<Bean>())

export const findAllByUser = (userId: UserId): Promise<Bean[]> =>
  memoizedPerRequest(`beans:all:${userId}`, async () => {
    const snap = await beans().where('userId', '==', userId).orderBy('createdAt', 'desc').get()
    return snap.docs.map((doc) => doc.data())
  })

export const findBy = async (userId: UserId, id: BeanId): Promise<Bean | undefined> => {
  const doc = await beans().doc(id).get()
  const data = doc.data()
  return data && data.userId === userId ? data : undefined
}

export const save = async (bean: Bean, batch?: WriteBatch): Promise<Bean> => {
  const ref = beans().doc(bean.id)
  if (batch) batch.set(ref, bean)
  else await ref.set(bean)
  return bean
}
```

**Aggregate + satellite** (as in `recipe`): keep a light pointer doc in one collection and
heavy append-only rows in another, keyed deterministically:

```ts
const versions = () =>
  db().collection('recipe-versions').withConverter(genericDataConverter<RecipeVersion>())
const versionDocId = (recipeId: RecipeId, number: VersionNumber) => `${recipeId}_${number}`
```

**Batch-load** by id with a single `getAll` (this is what loaders call), reusing the memoized
scan when it already ran this request for zero extra reads:

```ts
export const findManyByIds = async (userId: UserId, ids: RecipeId[]): Promise<Recipe[]> => {
  if (ids.length === 0) return []
  if (isInRequestCache(`recipes:all:${userId}`)) {
    const wanted = new Set(ids)
    return (await findAllByUser(userId)).filter((recipe) => wanted.has(recipe.id))
  }
  const snaps = await db().getAll(...ids.map((id) => recipes().doc(id)))
  return snaps
    .map((snap) => snap.data())
    .filter((recipe): recipe is Recipe => recipe !== undefined && recipe.userId === userId)
}
```

Firestore helpers live in `server/utils/firestore.ts`:

- `genericDataConverter<T>()` — typed reads; `Timestamp` → `Date`.
- `atomically(batch => …)` — one committed `WriteBatch`, all-or-nothing.
- `bulkSave(rows, save)` — bounded-concurrency individual sets (import/restore beyond the 500-op cap).
- `deleteInBatches(refs)` — chunked batch deletes.

## 5. Create the Query (`query.ts`)

> **Evans:** the public read interface. Thin pass-through; `'not-found' as const` on absence.

```ts
import * as repository from '~/domain/bean/infrastructure/repository'
import type { BeanId } from '~/domain/bean/types'
import type { UserId } from '~/domain/shared/types'

export namespace BeanQuery {
  export const all = async (userId: UserId) => repository.findAllByUser(userId)

  export const byId = async (userId: UserId, id: BeanId) => {
    const bean = await repository.findBy(userId, id)
    if (!bean) return 'not-found' as const
    return bean
  }
}
```

Name reads for the concept (`all`, `byId`, `versionsOf`) — never `getAll`/`fetchX`.

## 6. Create the Command (`command.ts`)

> **Evans:** the public write interface. **Wlaschin:** Railway-Oriented Programming — the
> return type enumerates every legitimate outcome (the entity, or a string sentinel).

Return the entity on success, a bare string sentinel on an expected business miss. Multi-doc
writes go through `atomically`. See [error-handling.md](./error-handling.md).

```ts
import * as repository from '~/domain/bean/infrastructure/repository'
import { randomBeanId } from '~/domain/bean/primitives'
import type { Bean, BeanId, BeanName, Roast } from '~/domain/bean/types'
import type { UserId } from '~/domain/shared/types'

export namespace BeanCommand {
  export const add = async (
    userId: UserId,
    input: { name: BeanName; roast: Roast },
  ): Promise<Bean> => {
    const bean: Bean = { id: randomBeanId(), userId, ...input, createdAt: new Date() }
    return repository.save(bean)
  }

  export const remove = async (
    userId: UserId,
    id: BeanId,
  ): Promise<undefined | 'not-found'> => {
    const bean = await repository.findBy(userId, id)
    if (!bean) return 'not-found' as const
    await repository.remove(id)
    return undefined
  }
}
```

Atomic multi-doc write (from `recipe`), enlisting both docs in one batch:

```ts
return atomically(async (batch) => {
  await repository.save(recipe, batch)
  await repository.saveVersion(firstVersion(recipe, origin, input), batch)
  return recipe
})
```

## 7. Add the GraphQL Slice (`infrastructure/graphql/`)

See [graphql-patterns.md](./graphql-patterns.md) for the full patterns. In short:

- **enums.ts** — `builder.enumType('Roast', { values: { LIGHT: { value: 'light' }, … } })`
- **types.ts** — `builder.objectRef<Bean>('Bean').implement({ fields: … })`, exposing branded
  scalars. If you add a **satellite** field to `Recipe`/`Version`, graft it:
  `builder.objectField(RecipeType, 'beans', (t) => t.field({ …, resolve: (r, _a, { loaders }) => … }))`.
- **inputs.ts** — `builder.inputType('AddBeanInput', { fields: … })`
- **queries.ts** / **mutations.ts** — `builder.queryField`/`builder.mutationField`, delegating
  to `BeanQuery`/`BeanCommand`, mapping sentinels to `GraphQLError` with `extensions.code`.

If the domain declares a **new branded scalar**, register it in
`server/domain/shared/graphql/{builder.ts,scalars.ts}`.

## 8. Register in the Schema

Add side-effect imports to `server/domain/shared/graphql/schema.ts` in dependency order:

```ts
import '~/domain/bean/infrastructure/graphql/enums'
import '~/domain/bean/infrastructure/graphql/types'
import '~/domain/bean/infrastructure/graphql/inputs'
import '~/domain/bean/infrastructure/graphql/queries'
import '~/domain/bean/infrastructure/graphql/mutations'
```

Then regenerate the SDL and the iOS types:

```bash
bun run generate:graphql            # regenerates shared/schema.graphql
cd ios && apollo-ios-cli generate   # regenerates Generated/GraphQL
```

## 9. Write Tests

Co-located, `bun:test`. Valid suffixes: `.unit.test.ts` (pure logic), `.int.test.ts` (against
the fake Firestore), `.feat.test.ts`. There is **no BDD DSL**.

Integration tests mock Firestore and assert both behaviour **and read/write budgets**:

```ts
import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
const { BeanCommand } = await import('~/domain/bean/command')

let fake = resetFakeFirestore()
beforeEach(() => { fake = resetFakeFirestore() })

test('add persists a bean', async () => {
  const bean = await BeanCommand.add('user-1' as UserId, { name: 'Geisha' as BeanName, roast: 'light' })
  expect(fake.snapshot('beans').get(bean.id as string)?.roast).toBe('light')
})
```

- **Atomicity**: `expect(fake.directWrites).toEqual([]); expect(fake.batches.length).toBe(1)`.
- **Read budget**: `const before = fake.queryReads; …; expect(fake.queryReads - before).toBe(2)`.
- **Cache**: a second read in the same request should add `0` to `fake.queryReads`.

`business-rules.ts` (if any) requires 100% coverage in `business-rules.unit.test.ts`.

## Optional: Business Rules (`business-rules.ts`)

> **Wlaschin:** pure domain functions — trivially testable, no infrastructure.

Pure, **synchronous** functions extracted from complex commands. Names ARE the concept.
From `recipe`:

```ts
export const nextVersionNumber = (versionCount: VersionNumber) =>
  toVersionNumber(versionCount + 1)

// The recipe's best attempt across its cooked versions, or nothing when none was
// ever tried. Highest rating wins; a tie breaks toward the most recent version.
export const bestRating = (versions: RecipeVersion[]): RecipeVersion | undefined =>
  versions
    .filter(isRated)
    .reduce<RatedVersion | undefined>(
      (best, version) =>
        best === undefined ||
        version.rating > best.rating ||
        (version.rating === best.rating && version.number > best.number)
          ? version
          : best,
      undefined,
    )
```

Rules: no `useStorage`, no `async` (both fail the arch test); 100% coverage; name the concept
(`bestRating`/`versionToOpen`, never `computeBestRating`); functional style — `map`/`filter`/`reduce`,
no imperative `for`/`while` loops (see [code-style.md](./code-style.md)).

## Optional: Use Case (`use-case.ts`)

> **Evans:** Application Service — coordinates several bounded contexts, owns no business logic.

Use when a route orchestrates multiple domains. Goes through public `Command`/`Query`
namespaces only — **never a repository, never storage** (enforced).

```ts
import { RecipeCommand } from '~/domain/recipe/command'
import { RecipeQuery } from '~/domain/recipe/query'
import { Ai } from '~/system/ai'

export namespace ProposalUseCase {
  // Ask the AI for the next version after an attempt. Reads the tried version through
  // the recipe domain's public Query, feeds it to the AI engine and brands the
  // result — a cross-boundary orchestration (recipe + ai) that persists nothing.
  export const fromAttempt = async (
    userId: UserId,
    recipeId: RecipeId,
    versionNumber: VersionNumber,
  ) => {
    const recipe = await RecipeQuery.byId(userId, recipeId)
    if (recipe === 'not-found') return 'not-found'
    const version = await RecipeQuery.versionBy(recipeId, versionNumber)
    if (version === 'not-found') return 'not-found'
    const proposal = await Ai.proposeNext(/* recipe + version + its attempt outcome */)
    return brandProposal(recipe.type, proposal)
  }

  // Accepting a proposal threads `basedOn` back into the recipe domain's command.
  export const accept = (userId: UserId, recipeId: RecipeId, proposal: AcceptedProposal) =>
    RecipeCommand.addVersion(userId, recipeId, { basedOn: proposal.basedOn /* …content */ })
}
```

Names carry intent (`fromAttempt`, `accept`, never `handleProposal`). `proposal` is the only
domain that imports `~/system/ai`, and it depends one-way on `recipe` (never the reverse).

## Checklist

- [ ] `types.ts` with branded types (no Zod)
- [ ] `primitives.ts` with Zod constructors (imports `ts-brand` + `zod`)
- [ ] `infrastructure/repository.ts` (the only `db()` site; converter on every collection; `userId`-scoped)
- [ ] `query.ts` (public read namespace, `'not-found'` sentinel)
- [ ] `command.ts` (public write namespace, sentinels, `atomically` for multi-doc writes)
- [ ] `infrastructure/graphql/{enums,types,inputs,queries,mutations}.ts`
- [ ] New branded scalars registered in `shared/graphql/{builder,scalars}.ts`
- [ ] Satellite fields (if any) resolved through a loader in `shared/graphql/loaders.ts`
- [ ] Side-effect imports added to `shared/graphql/schema.ts`
- [ ] Tests co-located (`.int.test.ts` with read-budget assertions; `.unit.test.ts` for rules)
- [ ] `bun run generate:graphql` + `apollo-ios-cli generate` if the schema changed
- [ ] `bun run prepare && bun tsc --noEmit` passes; `bun test` green
- [ ] (optional) `business-rules.ts` (pure/sync, 100% coverage) / `use-case.ts` (no repo access)
