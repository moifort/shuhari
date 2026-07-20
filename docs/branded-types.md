# Branded Types + Validation Constructors

Portable rules — nothing here names this project. The examples use a fictional `bean` domain; the
brands this repo actually owns are listed in [domain-guide.md](domain-guide.md#the-brands-in-this-repo).

## Why

Nominal types ([ts-brand](https://github.com/kourge/ts-brand)) prevent semantically different
values from being mixed (a `BeanId` is not a `UserId`, even though both are strings), and a
validation library ([Zod](https://zod.dev/)) makes the brand a *proof*: a value that carries the
brand has already been validated.

Two DDD concepts at once: Evans's **Value Objects** (defined by their value, not an identity) and
Wlaschin's **making illegal states unrepresentable** — once branded, no downstream code re-checks.

The split is strict, and worth enforcing with an architecture test:

- **`types.ts`** declares the brands — imports the branding library only, no validation library.
- **`primitives.ts`** declares the constructors — imports **both**.

## The pattern

### 1. Declare the brand (`types.ts`)

```ts
import type { Brand } from 'ts-brand'

export type BeanId = Brand<string, 'BeanId'>
export type BeanName = Brand<string, 'BeanName'>
export type BatchNumber = Brand<number, 'BatchNumber'>
```

### 2. Write the constructor (`primitives.ts`)

Parse, then brand — one factory per brand, named exactly like the type:

```ts
import { make } from 'ts-brand'
import { z } from 'zod'
import type { BeanId as BeanIdType, BeanName as BeanNameType } from '~/domain/bean/types'

export const BeanId = (value: unknown) => {
  const v = z.string().uuid().parse(value)
  return make<BeanIdType>()(v)
}

export const BeanName = (value: unknown) => {
  const v = z.string().trim().min(1).max(200).parse(value)
  return make<BeanNameType>()(v)
}

// A convenience generator for new ids.
export const randomBeanId = () => BeanId(crypto.randomUUID())
```

### 3. Validate at the boundary, once

Raw input is validated where it enters — the API scalar — and never again. Inside the domain,
values are already branded. See
[graphql-best-practices.md](./graphql-best-practices.md#validate-at-the-boundary-once-through-scalars).

**Never `as SomeBrand` on raw input.** The cast bypasses the only thing the brand promises.

## Brands are primitives at runtime

The brand is **compile-time only**: a branded string IS a `string`, a branded number IS a `number`.
Never wrap one with `String()` / `Number()`, and use it directly in arithmetic or string operations.

## Enum / union brands parse, they don't `make`

A string-literal union lives as a `const` tuple in `types.ts` and is parsed — then cast to the union
type — in `primitives.ts`. Casting an already-validated value to its own union is the one safe cast:

```ts
// types.ts
export const ROAST_VALUES = ['light', 'medium', 'dark'] as const
export type Roast = (typeof ROAST_VALUES)[number]

// primitives.ts
export const Roast = (value: unknown) => z.enum(ROAST_VALUES).parse(value) as RoastType
```

## Coerce before validating when the wire is loose

For values that may arrive as strings (query params, JSON from a model), preprocess inside the
constructor rather than at every call site:

```ts
export const BatchNumber = (value: unknown) => {
  const v = z
    .preprocess((n) => (typeof n === 'string' ? Number(n) : n), z.number().int().min(1))
    .parse(value)
  return make<BatchNumberType>()(v)
}
```

## Every brand exposed in the API gets its own scalar

A branded type that appears in the schema has a matching custom scalar, whose `parseValue` runs the
constructor. Resolvers then receive **pre-validated branded arguments** and never call a constructor
themselves; invalid input fails before the resolver runs. Adding a brand to the schema means adding
it in three places: the builder's scalar map, the scalar registration, and the client's codegen
scalar mapping.

## Where brands live

Cross-domain primitives (a user id, a count) belong to a shared module; everything else belongs to
the domain that owns the concept. A brand imported from another domain is a sign the concept is in
the wrong context.
