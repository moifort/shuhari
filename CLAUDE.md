# Shuhari - Project Directives

守破離 — *Shu* (follow the rule), *Ha* (break it), *Ri* (transcend it). A culinary
experimentation notebook: import a recipe, run it, rate the trial, let the AI
propose the next iteration, promote a version once it scores high enough.

## Language

Everything versioned and technical is written in **English**: commit messages, code, code comments, and documentation (README, this file). The **only** French in the repo is user-facing copy — `CHANGELOG.md` entries and the iOS app's on-screen text. Never mix languages in a commit message or a comment.

## Build & Verification Commands

- **Backend typecheck**: `bun tsc --noEmit`
- **Regenerate types** (if routes changed): `bun run prepare` (= `generate:assets` + `nitro prepare`); run it before `bun tsc`
- **Dev server**: `bun run dev` — Nitro on `http://localhost:3000` (GraphQL at `POST /graphql`)
- **Unit tests**: `bun test` (or `bun run test` to regenerate assets first)
- **Test coverage**: `bun run test:coverage`
- **Linter**: `bun run lint` (`bunx biome check`); autofix with `bun run lint:fix`
- **Runtime**: always use `bun`/`bunx`, never `npm`/`npx`
- **GraphQL codegen** (if the schema changed): `bun run generate:graphql` (regenerates `shared/schema.graphql`), then `cd ios && apollo-ios-cli generate`
- **iOS build**:
  ```
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project ios/Shuhari.xcodeproj -scheme Shuhari -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' build
  ```

## Development Workflow

> **Git commit & push rules live in [docs/git-workflow.md](docs/git-workflow.md)** — read it at
> the start of any coding session. This section is the quick reference.

1. Always verify the build before committing (backend `bun tsc --noEmit` + `xcodebuild` depending on what was touched)
2. Run `bun run prepare` before `bun tsc` if routes were added/modified
3. After each completed task: run an expert code review (`superpowers:requesting-code-review`) before committing
4. **Commit freely, one task = one commit**: commit each finished task without asking — you decide the boundaries. Keep tasks in separate commits so a rollback is a clean `git revert`; never bundle several tasks into one commit. English messages, Conventional Commits, `Co-Authored-By:` trailer.
5. **Rollback** = `git revert` the task's commit (see [docs/git-workflow.md](docs/git-workflow.md)).
6. **Never push until the user explicitly says "push".** Commits accumulate locally; pushing is user-gated.

### Push protocol (only when the user says "push")

1. **Re-analyze & reshape the pending commits** (`git log origin/<branch>..HEAD`): squash/regroup related ones, rewrite messages, and **elide undone work** — a feature + its revert must collapse and leave no trace on the remote.
2. **Biome autofix**: run `bun run lint:fix`, confirm `bun run lint` is clean, and commit any changes — CI's `biome check` lints everything (incl. asset-catalog JSON), and local `bun test` doesn't cover it.
3. **README** (`README.md`): update the features / tech-stack sections if the pushed work changed them.
4. **Changelog** (`CHANGELOG.md`): add user-facing entries (in French) under `## Unreleased`, then run `bun run generate:assets` to regenerate `server/system/changelog-content.ts` (the iOS-facing asset served via GraphQL — never edit it by hand).
5. Push.

## Backend Patterns (TypeScript / Nitro)

> Extended guides live in `docs/`: [architecture](docs/architecture.md),
> [domain-guide](docs/domain-guide.md), [graphql-patterns](docs/graphql-patterns.md),
> [branded-types](docs/branded-types.md), [code-style](docs/code-style.md),
> [error-handling](docs/error-handling.md), [migrations](docs/migrations.md). This section is the
> quick reference; the docs go deeper with examples.

- **Stack**: Bun + Nitro 2.13 (`preset firebase`, gen 2, nodejs22, `europe-west3`) + Apollo Server 5 + Pothos 4 + firebase-admin (native Firestore) + Zod + ts-brand. DDD/CQRS strict.
- **Domains** live in `server/domain/{recipe,trial,proposal,home,portability,changelog,shared}`; system concerns in `server/system/{ai,firebase,config,migration,request-cache}`.
- Domain architecture: `server/domain/{domain}/types.ts`, `primitives.ts`, `command.ts`, `query.ts`, `infrastructure/repository.ts`, `infrastructure/graphql/{types,queries,mutations,inputs,enums}.ts`
- **`business-rules.ts`** (optional): pure functions (no IO, no async) extracted from complex commands. Function names ARE the business concept (`readyToPromote`, `nextVersionNumber`, `applyProposalToParams` — never `computeX`, `getX`). 100% test coverage (`business-rules.unit.test.ts`)
- **`use-case.ts`** (optional): multi-domain orchestrations when a route needs to coordinate several commands/queries. Names carry business intent (never `handleX`, `processX`). No direct storage access.
- Branded types with `ts-brand` + Zod validation constructors in `primitives.ts` (e.g. `RecipeId`, `VersionNumber`, `Note`). Discriminated results for absence/errors (`'not-found' as const`, `'nothing-to-test' as const`) — no exceptions for control flow.
- **Storage: native Firestore** (`firebase-admin`) via `db()` from `server/system/firebase.ts`, only inside `infrastructure/repository.ts`. Helpers in `server/utils/firestore.ts`:
  - `genericDataConverter<T>()` — typed reads, recursively turns `Timestamp` → `Date`. Always `.withConverter(genericDataConverter<T>())` on a collection ref.
  - `atomically(batch => …)` — enlist a handful of writes into one `WriteBatch`, committed once (all-or-nothing). Reads inside see pre-batch state.
  - `bulkSave(rows, save)` — bounded-concurrency individual sets for import/restore (row counts exceed the 500-op batch cap).
  - `deleteInBatches(refs)` — chunked batch deletes.
  - Aggregate root + append-only satellite: a `recipes` pointer doc + heavy `recipe-versions` keyed `${recipeId}_${number}`.
- **Request cache** (`server/system/request-cache.ts`): `memoizedPerRequest(key, fn)` / `isInRequestCache(key)` — collapse repeated reads within a single request (e.g. reuse the memoized full scan instead of a `getAll`).
- **GraphQL** (Apollo Server + Pothos, single endpoint `POST /graphql`): satellite `RecipeType` fields (currentVersion, toTest, versions, variations, trials, pendingProposal) must never scan a collection or read one doc per parent row (N+1). They resolve through the per-request loaders in `server/domain/shared/graphql/loaders.ts` (memoized + micro-batched by key, built per request on the GraphQL context) — a page of recipes selecting `currentVersion` costs one `getAll`, an unselected satellite costs nothing. Read budgets are asserted in tests via `fake.reads`/`fake.docReads`/`fake.queryReads`.
- **Naming**: function names carry the business concept, not the technical pattern. The name IS the rule or action.
- **Tests**: `*.unit.test.ts` with `bun:test`. Firestore is mocked via `server/test/fake-firestore.ts` (`mock.module('~/system/firebase', () => ({ db: fakeDb }))`) — records batches, direct writes and read counts (`fake.reads`) to assert atomicity and read budgets.
- Formatter: Biome (spaces width 2, single quotes, no semicolons, line width 100).

## Key Business Rules

- **Four recipe types** (`RECIPE_TYPE_VALUES`): `cafe`, `cocktail`, `plat`, `tmx` (Thermomix).
- **One variable per iteration for `cafe` / `cocktail`** — the AI proposal may change exactly one parameter per iteration for these two types (the scientific single-variable method); `plat` / `tmx` may change several. Enforced in the `proposal` domain.
- **Iteration vs variation**: an accepted iteration appends version `n+1` on the same recipe and marks it `toTest`; an accepted variation forks a brand-new recipe (`derivedFrom` the parent) with its own fresh v1 lineage.
- **Promotion**: a trial promotes its version to `currentVersion` (the reproducible reference) only when it ran against the pending `toTest` version and its note ≥ `PROMOTION_NOTE` (8). See `recipe/business-rules.ts`.
- **Reproducibility**: a `Trial.realParams` stores *only* the parameters that actually deviated from the version's target — replaying an essai overlays the target params with these deviations.

## Database Migrations

- Location: `server/system/migration/`
- Forward-only sequential migrations, no rollback
- Meta tracked in the Firestore collection `migration-meta` (doc `state`)
- Triggered by `POST /admin/migrate` (`server/routes/admin/migrate.post.ts`), called during provisioning / CI deploy — no boot-time plugin
- To add a migration: create `server/system/migration/migrations/NNNN-name.ts`, register in `migrations/index.ts`
- Migration `version` uses branded `MigrationVersion` (starts at 1; version 0 is the reserved sentinel)
- Migrations receive a `MigrationContext` with the Firestore `db`, return `MigrationResult` (`{ ok: true, transformed }` or `{ ok: false, error }`)
- Runner (`runner.ts`) wraps each migration in try/catch — migrations don't need their own error handling
- **When to migrate**: renaming a field, changing a field's structure, changing enum values (e.g. a new `RecipeType`), removing stale data
- **No migration needed**: adding a new optional (`?`) field, adding a new collection, changing query logic/routes

## iOS Patterns (SwiftUI)

> Full iOS guide: [docs/ios-guide.md](docs/ios-guide.md).

- Target: iOS 26.0, Swift 6 (strict concurrency). Xcode project `ios/Shuhari.xcodeproj`, scheme `Shuhari`, bundle id `com.polyforms.shuhari.app`, team `46C337T7YN`.
- Architecture: MVVM with `@Observable`. `@MainActor` on ViewModels, `Sendable` on model types. Apollo iOS codegen for typed GraphQL operations.
- Style: **Liquid Glass** = native iOS 26 components (no custom re-skins).
- Feature structure: `ios/Shuhari/Features/{Feature}/` with `pages/`, `organisms/`, `molecules/` subdirectories; shared atoms in `ios/Shuhari/Shared/Components/`.
- **Primitive-first views**: leaf views receive only primitives (`String`, `Int`, `Bool`, `Date?`, enums, closures) — never domain structs. Use nested `Item` structs for 5+ parameters.
- **Previews as Storybook**: every component below page level must be previewable without a running server.
- **Pages = coordinators**: handle loading, error, sheets, toolbar, API calls; map domain models to primitives for children. **Organisms** can accept domain structs when they break them down into primitives for child sections.
- Xcode uses `fileSystemSynchronizedGroups` (no need to manually add files). `DEVELOPER_DIR` is required because `xcode-select` points to CommandLineTools.
- Auth: Firebase Auth + Sign in with Apple (mono-user, but real auth).

## App Store Distribution

Build with the latest **final** Xcode — never a beta/RC, and never an older release once a newer final ships. Both trigger **ITMS-90111** (Unsupported SDK or Xcode version) on upload.

If the dev Mac runs a **beta macOS**, archives get a prerelease `BuildMachineOSBuild` stamp that App Store validation also rejects with ITMS-90111. After archiving, patch it to the latest **public** macOS build number *before* `-exportArchive` (export re-signs, so the patch survives):

```bash
# after `xcodebuild ... archive`, before `-exportArchive`:
plutil -replace BuildMachineOSBuild -string '<latest public macOS build>' \
  build/Shuhari.xcarchive/Products/Applications/Shuhari.app/Info.plist
```

Look up the current public macOS build at https://developer.apple.com/news/releases. Verify `DTXcodeBuild`/`DTSDKBuild` are untouched, then export. The clean alternative is to archive on a non-beta macOS (e.g. a CI macOS runner with the final Xcode) — no patch needed. Bump `CURRENT_PROJECT_VERSION` in `project.pbxproj` for every new upload.

## Gemini API Key & Secrets

- The AI (recipe import + iteration proposals) is **Gemini 2.5 Flash** in `server/system/ai/`. Its key is read from `NITRO_GOOGLE_API_KEY` (runtime config `googleApiKey`).
- `POST /admin/migrate` is gated by the admin token (`NITRO_ADMIN_TOKEN`, runtime config `adminToken`).
- Local `.env` (see `.env.example`):
  ```
  NITRO_GOOGLE_API_KEY=...
  NITRO_ADMIN_TOKEN=your-admin-token
  NITRO_SENTRY_DSN=         # optional
  ```
- In production, secrets live in GCP Secret Manager (project `shuhari-polyforms`), provisioned by the infra. To rotate the Gemini key: update Secret Manager (or `.env` locally) — never commit it.

## iOS Simulator

- Device: iPhone 17, OS 26.2
