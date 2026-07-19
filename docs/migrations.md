# Migration System

> **Dated note (2026-07): production Firestore is empty.** The app is pre-first-release; no
> real data exists to transform. Schema-shape changes (renamed/removed fields, new required
> fields) therefore need **no migration** while that holds — the `migrations` array is still
> empty, so the next one will be `0001`. Before writing a migration, check whether real data
> has landed since; once the App Store release ships and data exists, delete this note and
> follow the rules below again.

## Overview

Forward-only, sequential Firestore migrations. Meta is tracked in the Firestore collection
`migration-meta`, document `state`. Migrations are triggered on demand by `POST /admin/migrate`
(during provisioning / CI deploy) — there is **no** boot-time plugin and nothing calls
`process.exit`.

Location: `server/system/migration/`.

```
server/system/migration/
├── types.ts              # Migration, MigrationContext, MigrationResult, MigrationMeta
├── primitives.ts         # MigrationVersion / MigrationName constructors
├── runner.ts             # runMigrations(migrations)
└── migrations/
    ├── index.ts          # export const migrations: Migration[] = []
    └── NNNN-name.ts       # individual migrations
```

## When to Migrate

**Migration needed:**
- Renaming a field
- Changing a field's structure
- Changing enum values (e.g. a new `RecipeType`)
- Removing stale data

**No migration needed:**
- Adding a new optional (`?`) field
- Adding a new collection
- Changing query logic or routes

## Types

```ts
export type MigrationVersion = Brand<number, 'MigrationVersion'>
export type MigrationName = Brand<string, 'MigrationName'>

export type MigrationContext = { db: Firestore }

export type Migration = {
  version: MigrationVersion
  name: MigrationName
  migrate: (ctx: MigrationContext) => Promise<MigrationResult>
}

export type MigrationResult = { ok: true; transformed: number } | { ok: false; error: string }
```

The context hands you the native Firestore `db` directly — a migration reads and writes
collections itself (it is infrastructure, not a domain, so it bypasses repositories).

## Creating a Migration

### 1. Create the file

`server/system/migration/migrations/0001-rename-foo-to-bar.ts`:

```ts
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'

export const migration0001: Migration = {
  version: MigrationVersion(1),
  name: MigrationName('rename-foo-to-bar'),
  migrate: async ({ db }) => {
    const snap = await db.collection('recipes').get()
    let transformed = 0
    for (const doc of snap.docs) {
      const data = doc.data()
      if ('foo' in data) {
        await doc.ref.update({ bar: data.foo, foo: FieldValue.delete() })
        transformed++
      }
    }
    return { ok: true, transformed }
  },
}
```

The runner wraps each migration in try/catch, so a migration does **not** need its own error
handling — throwing (or returning `{ ok: false, error }`) marks it failed and stops the run.

### 2. Register it

`server/system/migration/migrations/index.ts` (forward-only, in ascending order):

```ts
import { migration0001 } from '~/system/migration/migrations/0001-rename-foo-to-bar'
import type { Migration } from '~/system/migration/types'

export const migrations: Migration[] = [migration0001]
```

## How It Works (`runner.ts`)

1. `runMigrations(migrations)` reads `migration-meta/state`; absent → version `0` (the reserved
   sentinel — real migrations start at `1`).
2. It filters `version > current`, sorts ascending, and applies each in turn.
3. After each success it writes back `{ version, appliedAt }`, then logs one `console.info` line.
4. On a failed/`throw`n migration it returns `{ outcome: 'failed', version, error }` and stops.
5. It returns `{ outcome: 'up-to-date' }`, `{ outcome: 'migrated', from, to, applied }`, or the
   failure shape.

## Testing a Migration

Co-locate an integration test `NNNN-name.int.test.ts` next to the migration. Mock Firestore with the
in-memory fake, seed the pre-migration documents, run `migrate`, then assert the transformed shape:

```ts
import { expect, test } from 'bun:test'
import { resetFakeFirestore } from '~/test/fake-firestore'

const { migration0001 } = await import('./0001-rename-foo-to-bar')

test('renames foo to bar', async () => {
  const fake = resetFakeFirestore()
  fake.seed('recipes', 'r1', { id: 'r1', foo: 42 })

  const result = await migration0001.migrate({ db: fake.db })

  expect(result).toEqual({ ok: true, transformed: 1 })
  expect(fake.snapshot('recipes').get('r1')).toEqual({ id: 'r1', bar: 42 })
})
```

## Trigger — `POST /admin/migrate`

`server/routes/admin/migrate.post.ts` runs the migrations and sets **HTTP 500** on failure, so a
CI step gating on `curl -fsS` fails the deploy:

```ts
export default defineEventHandler(async (event) => {
  const result = await runMigrations(migrations)
  if (result.outcome === 'failed') setResponseStatus(event, 500)
  return result
})
```

The `/admin/*` routes are gated by the admin bearer token (`middleware/auth.ts`, `adminToken`),
**not** a Firebase user. The bootstrap / GitHub Actions deploy calls this endpoint after
`terraform apply`.

## Rules

- `MigrationVersion` is a branded integer (`min 0`, string-coercible); `0` is the reserved
  sentinel, versions start at `1`.
- Migrations are **forward-only** — no rollback mechanism.
- The runner owns error handling; migrations stay focused on the transform.
- **Never run migrations locally against production data** — they run through `POST /admin/migrate`
  during provisioning / deploy.
- **Firestore rejects `undefined` values** — when restructuring a document, only copy fields that are
  actually present (`if (value != null) …`).
