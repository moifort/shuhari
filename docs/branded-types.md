# Branded Types + Zod

## Overview

We use [ts-brand](https://github.com/kourge/ts-brand) to create nominal types that prevent
accidental mixing of semantically different values (e.g. `RecipeId` vs `TrialId`), combined with
[Zod](https://zod.dev/) for runtime validation.

This implements two DDD concepts: Evans' **Value Objects** (defined by their value, no identity)
and Wlaschin's **making illegal states unrepresentable** — once a value exists as a branded
type, it has already been validated, so no downstream code re-checks it.

The split is strict and enforced by `server/architecture.unit.test.ts`:

- **`types.ts`** declares the brands (imports `ts-brand` only, no Zod).
- **`primitives.ts`** declares the constructors (must import **both** `ts-brand` and `zod`).

## Pattern

### 1. Declare the brand (`types.ts`)

```ts
import type { Brand } from 'ts-brand'

export type RecipeId = Brand<string, 'RecipeId'>
export type VersionNumber = Brand<number, 'VersionNumber'>
export type ParamValue = Brand<string, 'ParamValue'>
```

### 2. Write the Zod constructor (`primitives.ts`)

`zod` parse → `ts-brand` `make`:

```ts
import { make } from 'ts-brand'
import { z } from 'zod'
import type { RecipeId as RecipeIdType } from '~/domain/recipe/types'

export const RecipeId = (value: unknown) => {
  const v = z.string().uuid().parse(value)
  return make<RecipeIdType>()(v)
}

// A convenience generator for new ids.
export const randomRecipeId = () => RecipeId(crypto.randomUUID())
```

Real constraints from `recipe/primitives.ts`:

```ts
export const RecipeTitle = (value: unknown) => {
  const v = z.string().trim().min(1).max(200).parse(value)
  return make<RecipeTitleType>()(v)
}
export const ParamValue = (value: unknown) => {
  const v = z.string().trim().min(1).max(120).parse(value)
  return make<ParamValueType>()(v)
}
```

### 3. Validate at the boundary

Validation happens **once**, at the GraphQL scalar boundary. Each branded scalar's `parseValue`
runs its constructor (see [graphql-patterns.md](./graphql-patterns.md)); a `ZodError` becomes a
`BAD_USER_INPUT` `GraphQLError`. Inside the domain, values are already branded — never
re-validate.

## Enum / Union Brands

String-literal unions live as a `const` tuple in `types.ts` and are parsed (not `make`d) in
`primitives.ts` — the parse result is cast to the union type:

```ts
// types.ts
export const RECIPE_TYPE_VALUES = ['cafe', 'cocktail', 'plat', 'tmx'] as const
export type RecipeType = (typeof RECIPE_TYPE_VALUES)[number]

// primitives.ts
export const RecipeType = (value: unknown) =>
  z.enum(RECIPE_TYPE_VALUES).parse(value) as RecipeTypeType
```

**Never use `as SomeType` on raw input** — always go through the Zod constructor. (The cast above
is on an already-Zod-validated value, which is safe.)

## Numeric Types with String Coercion

For values that may arrive as strings, preprocess before validating:

```ts
export const VersionNumber = (value: unknown) => {
  const v = z
    .preprocess((n) => (typeof n === 'string' ? Number(n) : n), z.number().int().min(1))
    .parse(value)
  return make<VersionNumberType>()(v)
}
```

## Shared Types

Cross-domain primitives live in `server/domain/shared/`:

- `UserId` — Firebase Auth user identifier (non-empty string), in `types.ts` / `primitives.ts`
- `Count` — a branded number (constructed from an already-numeric value: `make<CountType>()(value)`)

Domain-specific brands stay in their own domain — e.g. `Note`, `Remarks`, `TrialId` in `trial`;
`RecipeId`, `VersionNumber`, `Param*`, `Tmx*` in `recipe`.
