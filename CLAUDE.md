# Shuhari - Project Directives

守破離 — *Shu* (follow the rule), *Ha* (break it), *Ri* (transcend it). A culinary
experimentation notebook: import a recipe, cook a version, rate the attempt, let the AI
propose the next iteration, and open the best-rated version by default.

## Language

Everything versioned and technical is written in **English**: commit messages, code, code comments, and documentation (`README.md`, `docs/`, this file). This includes `CHANGELOG.md`, the English source of truth. That covers identifiers, folder and file names, GraphQL descriptions, AI prompts, test names, and — on iOS — accessibility *identifiers*.

**Enum values, unions and discriminants are English technical symbols** (`DISH`/`dish`, `STARTER`/`starter`, `ai-proposal`): the schema never speaks the user's language, the app translates them (`RecipeType.swift` maps `.dish` to the label "Plat").

The **only** French in the repo is user-facing copy — `CHANGELOG.fr.md` (the copy served to the app, plus its generated asset `server/system/changelog-content.ts`) and the iOS app's on-screen text (`Text`, `label`, `navigationTitle`, `accessibilityLabel`, preview names) — and French **data values** quoted as examples in code/prompts (Thermomix speeds, ingredient names) plus the import fallback title. Never mix languages in a commit message or a comment. Control: `grep -rnP '[\x{00C0}-\x{00FF}]' server/` (the accented-letter range) must only return those exceptions. Full rules: [docs/code-style.md](docs/code-style.md#language).

## Collaboration

> Full working agreement: [docs/collaboration.md](docs/collaboration.md) — read it at the start
> of any session. Key rules:

- **Docs are the spec**: align code to `docs/`, never the reverse; `docs/code-style.md` is law and is never edited to match the code (it changes only on an explicit user request). Corrections given in conversation are applied repo-wide **and** codified in the matching doc, in the same task.
- **Rules generic, wiring specific**: a practice that would hold in any codebase goes in a `*-best-practices.md` with neutral examples; how this repo implements it goes in the matching project guide, which links to the rule.
- **Design talk is not a go**: in architecture discussions, "je veux faire X" is design intent — implement only on an explicit "vas-y" / "implémente" / "lance".
- **Every plan opens with a "Domaines impactés" block** (Créés / Modifiés / Supprimés) before the body.
- **Never open a PR**: on "push", everything goes straight to `origin/main`.
- **No machine-local assistant memory**: collaboration learnings are written into `docs/`, nothing else.
- **Ops autonomy**: execute everything CLI-doable yourself; hand off only credential-gated steps, with numbered instructions.

## Build & Verification Commands

- **Backend typecheck**: `bun tsc --noEmit`
- **Regenerate types** (if routes changed): `bun run prepare` (= `generate:assets` + `nitro prepare`); run it before `bun tsc`
- **Dev server**: `bun run dev` — Nitro on `http://localhost:3000` (GraphQL at `POST /graphql`)
- **Unit tests**: `bun test` (or `bun run test` to regenerate assets first)
- **Test coverage**: `bun run test:coverage`
- **Linter**: `bun run lint` (`bunx biome check`); autofix with `bun run lint:fix`
- **Runtime**: always use `bun`/`bunx`, never `npm`/`npx`
- **GraphQL codegen** (if the schema changed): `bun run generate:graphql` (regenerates `shared/schema.graphql`), then `bun run generate:ios`
- **iOS build**:
  ```
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project ios/Shuhari.xcodeproj -scheme Shuhari -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' build
  ```

## Development Workflow

> **Git commit & push rules live in [docs/git-workflow.md](docs/git-workflow.md)** (this repo's
> policy; the portable rules are in [docs/git-best-practices.md](docs/git-best-practices.md)) — read it at
> the start of any coding session. This section is the quick reference.

1. Always verify the build before committing (backend `bun tsc --noEmit` + `xcodebuild` depending on what was touched)
2. Run `bun run prepare` before `bun tsc` if routes were added/modified
3. After each completed task: review the diff yourself, **inline**, before committing — never delegate to a subagent (see [docs/collaboration.md](docs/collaboration.md#work-inline-never-through-subagents))
4. **Commit freely, one task = one commit**: commit each finished task without asking — you decide the boundaries. Keep tasks in separate commits so a rollback is a clean `git revert`; never bundle several tasks into one commit. English messages, Conventional Commits, `Co-Authored-By:` trailer.
5. **Close every task with the surfaces touched, then the diff size** (see [docs/collaboration.md](docs/collaboration.md#closing-a-task-surfaces-then-diff-size)):
   - one sentence saying which of **the database**, **the backend** and **the iOS app** the task changed, and which it left alone (e.g. "Back et app iOS modifiés, BDD inchangée") — that is the deployment blast radius;
   - then run `git show --stat HEAD | tail -1` and state the lines added / removed (e.g. "+412 / −587 over 23 files"). A refactor that only adds is a refactor that forgot to delete — the number is the check.
6. **Rollback** = `git revert` the task's commit (see [docs/git-workflow.md](docs/git-workflow.md)).
7. **Never push until the user explicitly says "push".** Commits accumulate locally; pushing is user-gated.
8. **Never open a PR.** A "push" goes straight to `origin/main` (`git push origin HEAD:main`), whatever the working branch — see [docs/git-workflow.md](docs/git-workflow.md).

### Push protocol (only when the user says "push")

1. **Re-analyze & reshape the pending commits** (`git log origin/<branch>..HEAD`): squash/regroup related ones, rewrite messages, and **elide undone work** — a feature + its revert must collapse and leave no trace on the remote.
2. **Biome autofix**: run `bun run lint:fix`, confirm `bun run lint` is clean, and commit any changes — CI's `biome check` lints everything (incl. asset-catalog JSON), and local `bun test` doesn't cover it.
3. **iOS GraphQL API** (if the schema changed): run `bun run generate:graphql`, then `bun run generate:ios`, and commit the regenerated `shared/schema.graphql` + `ios/Shuhari/**/Generated` so the app's typed operations stay in sync with the deployed schema.
4. Push — straight to `origin/main` (`git push origin HEAD:main`), never via a PR; realign local `main` afterwards.
5. **Analyze the CI**: a push to `main` fires **Unit Tests** + **Deploy** — watch them (`gh run watch`, or `gh run list --branch main` + `gh run view <id> --log-failed` on failure). Not done until CI is green; fix any failure with a follow-up commit + push.

**Not at push time — the README nor the changelog.** Do **not** touch `README.md`, `CHANGELOG.md` or `CHANGELOG.fr.md` when pushing. The README is updated on its own, when asked. The changelog is written only at the moment of an iOS App Store release, as part of the release flow (see [App Store Distribution](#app-store-distribution)) — a normal `main` push carries no changelog change, and there is no CI date-stamp (versioning is manual).

## Backend Patterns (TypeScript / Nitro)

> Extended guides live in `docs/`, split in two: the **rules**, written project-agnostic —
> [ddd-best-practices](docs/ddd-best-practices.md), [graphql-best-practices](docs/graphql-best-practices.md),
> [code-style](docs/code-style.md), [branded-types](docs/branded-types.md),
> [error-handling](docs/error-handling.md) — and this repo's **wiring** —
> [architecture](docs/architecture.md), [domain-guide](docs/domain-guide.md),
> [graphql-patterns](docs/graphql-patterns.md), [migrations](docs/migrations.md),
> [readme-guide](docs/readme-guide.md), [collaboration](docs/collaboration.md). This section is the
> quick reference; the docs go deeper with examples.

- **Stack**: Bun + Nitro 2.13 (`preset firebase`, gen 2, nodejs22, `europe-west3`) + Apollo Server 5 + Pothos 4 + firebase-admin (native Firestore) + Zod + ts-brand. DDD/CQRS strict.
- **Domains** live in `server/domain/{recipe,proposal,shared}` (`recipe` is the only persisted domain; `proposal` is ephemeral — never stored — and the sole caller of `~/system/ai`); system concerns in `server/system/{ai,changelog,portability,firebase,config,migration,request-cache}`.
- Domain architecture: `server/domain/{domain}/types.ts`, `primitives.ts`, `command.ts`, `query.ts`, `infrastructure/repository.ts`, `infrastructure/graphql/{types,queries,mutations,inputs,enums}.ts`
- **Version content variant** (`recipe`): a version splits into a type-agnostic versioning *envelope* (`server/domain/recipe/version.ts` — `number`, `basedOn`, `change`, `origin`, `why`, `createdAt`, attempt outcome) and a `content` discriminated union under `server/domain/recipe/content/` (`types.ts` = `VersionContent = DishContent | ThermomixContent`; `dish.ts`; `thermomix.ts` with its `thermomixSteps`/`toThermomixSettings` rules). Adding a recipe type later (e.g. `cafe`) is one new file in `content/` + one AI-schema arm + iOS organisms — the envelope and lineage rules never touch `content`. See [docs/domain-guide.md](docs/domain-guide.md#adding-a-recipe-type).
- **`business-rules.ts`** (optional): pure functions (no IO, no async) extracted from complex commands. Function names ARE the business concept (`bestRating`, `versionToOpen`, `nextVersionNumber` — never `computeX`, `getX`). 100% test coverage (`business-rules.unit.test.ts`)
- **`use-case.ts`** (optional): multi-domain orchestrations when a route needs to coordinate several commands/queries. Names carry business intent (never `handleX`, `processX`). No direct storage access.
- Branded types with `ts-brand` + Zod validation constructors in `primitives.ts` (e.g. `RecipeId`, `VersionNumber`, `Rating`). Discriminated results for absence/errors (`'not-found' as const`) — no exceptions for control flow.
- **Storage: native Firestore** (`firebase-admin`) via `db()` from `server/system/firebase.ts`, only inside `infrastructure/repository.ts`. Helpers in `server/utils/firestore.ts`:
  - `genericDataConverter<T>()` — typed reads, recursively turns `Timestamp` → `Date`. Always `.withConverter(genericDataConverter<T>())` on a collection ref.
  - `atomically(batch => …)` — enlist a handful of writes into one `WriteBatch`, committed once (all-or-nothing). Reads inside see pre-batch state.
  - `bulkSave(rows, save)` — bounded-concurrency individual sets for import/restore (row counts exceed the 500-op batch cap).
  - `deleteInBatches(refs)` — chunked batch deletes.
  - Aggregate root + append-only satellite: a `recipes` pointer doc + heavy `recipe-versions` keyed `${recipeId}_${number}`.
- **Request cache** (`server/system/request-cache.ts`): `memoizedPerRequest(key, fn)` / `isInRequestCache(key)` — collapse repeated reads within a single request (e.g. reuse the memoized full scan instead of a `getAll`).
- **GraphQL** (Apollo Server + Pothos, single endpoint `POST /graphql`): satellite `RecipeType` fields (versions, versionToOpen, bestRating) must never scan a collection or read one doc per parent row (N+1). They resolve through the per-request `versionsByRecipe` loader in `server/domain/shared/graphql/loaders.ts` (memoized + micro-batched by key, built per request on the GraphQL context) — a page of recipes selecting `versionToOpen`/`bestRating` costs one `getAll`, an unselected satellite costs nothing. Read budgets are asserted in tests via `fake.reads`/`fake.docReads`/`fake.queryReads`.
- **Naming**: function names carry the business concept, not the technical pattern. The name IS the rule or action. **Ubiquitous language**: one business concept = one word, the one the feature speaks, used identically at every layer (domain, GraphQL, iOS, tests — the app's French copy being its translation). If the feature says "amélioration", the code says `improvement` everywhere — never a synonym (`wish`, `suggestion`) introduced by a single layer. See [docs/domain-guide.md](docs/domain-guide.md#ubiquitous-language).
- **Tests**: `*.unit.test.ts` with `bun:test`. Firestore is mocked via `server/test/fake-firestore.ts` (`mock.module('~/system/firebase', () => ({ db: fakeDb }))`) — records batches, direct writes and read counts (`fake.reads`) to assert atomicity and read budgets.
- Formatter: Biome (spaces width 2, single quotes, no semicolons, line width 100). Pattern matching: `ts-pattern` (`match().exhaustive()`); utilities: `lodash-es` (tree-shakeable) — the concrete picks behind the generic rules in [docs/code-style.md](docs/code-style.md).

## Key Business Rules

- **Two recipe types** (`RECIPE_TYPE_VALUES`): `dish`, `thermomix`. Ratings are `1..5`.
- **Version content is a discriminated union** (`server/domain/recipe/content/`): `VersionContent = DishContent | ThermomixContent`, tagged by `kind` (`'dish' | 'thermomix'`). `DishContent` = `ingredients` + plain-text `steps`; `ThermomixContent` = `ingredients` + nested `steps: ThermomixStep[]` where each `ThermomixStep = { text; settings }` (settings total — `{}` = a plain step). **Invariant `content.kind === recipe.type`** is enforced in `RecipeCommand.create`/`addVersion`, returning `'content-type-mismatch' as const` on a mismatch. GraphQL mirrors it: a `VersionContent` union (Pothos `unionType`, `resolveType` on `kind`) and a `VersionContentInput @oneOf { dish, thermomix }` (`isOneOf: true`).
- **Dish category** (`DISH_CATEGORY_VALUES`): `starter`, `main`, `dessert`, `soup`, `sauce`, `baking`, `drink`. Detected by the AI at import and held on the aggregate (never versioned — the recipe sheet's edit CTA can refile it via `updateRecipe`); the array order IS the library's sort rank, denormalized via `categoryRank`.
- **Linear lineage**: a recipe owns a chain of `RecipeVersion`s (`v1 → v2 → v3 …`). `RecipeVersion.basedOn` is the `VersionNumber` a version was iterated from (**absent** on v1, which iterates on nothing). No forks, no variations, no `derivedFrom`.
- **A version *is* an attempt**: its `content` (the `VersionContent` union — `ingredients` + `steps`) and lineage (`origin`/`change`/`basedOn`) are immutable; its outcome is overwritable. An attempt is not an entity. A version with no outcome yet is a *planned* attempt: no `executedAt`, no `rating` (the fields are **absent**, never `null`).
- **An attempt lands on the version it produces**, and only a remark-less cook lands on the version cooked:
  - **rating (and photo) without remarks** — nothing new is created, `RecipeCommand.recordAttempt` writes `rating` (1..5), `executedAt`, `photoPath` onto the version cooked and rewrites them in place on a re-cook (dropping the previous photo *and* remarks). `remarks` is optional here: a bare rating ends the flow.
  - **with remarks** — the cook asks for the next version, so its `rating`/`remarks`/`photoPath` are recorded on the version that answers it, via `RecipeCommand.addVersion`'s `attempt`. **The version iterated on is never touched.** Nothing at all is persisted until the proposal is accepted: refusing it loses the rating, by design.
- **No promotion — everything derived** (`recipe/business-rules.ts`): `bestRating` = the recipe's best-rated cooked version (highest rating; tie → most recent version), `undefined` when nothing was ever cooked; it drives the displayed rating. `versionToOpen` = the version the recipe sheet opens on: the best-rated version, else the latest (a recipe with no cook behind it). A version waiting to be cooked (`toTest`) never opens — the flask CTA is the only way in.
- **Improvement**: the second way to ask for a version, with no cook behind it — the user writes what they want changed and `ProposalUseCase.fromImprovement(userId, recipeId, versionNumber, improvement)` feeds it to the AI in place of the attempts (same ephemeral `Proposal`). Accepting it appends `n+1` **without** an attempt, which is the **sole** way a version gets `toTest: true`.
- **`toTest`** (`RecipeVersion.toTest?: true`, absent = not on the list): the versions waiting to be cooked, listed by the recipe sheet's flask CTA. Only an improvement raises it; it drops the moment the version is cooked — `recordAttempt` rewrites it away, and accepting an attempt-born proposal clears it on the version it answers (`basedOn`).
- **Iteration**: the attempt travels in the request — `ProposalUseCase.fromAttempt(userId, recipeId, versionNumber, { rating, remarks })` reads the version cooked and feeds both to the AI (→ `Proposal`, ephemeral, never stored); accepting it (`ProposalUseCase.accept`) appends version `n+1` via `RecipeCommand.addVersion` with `origin.kind = 'ai-proposal'`, threading `basedOn = the version cooked` and stamping that attempt as the new version's outcome. The app only asks for a proposal when remarks were written — a bare rating ends the flow. Import confirmation persists a fresh recipe + v1 (`origin.kind = 'import'`) via `RecipeCommand.create` (the `createRecipe` mutation).
- **AI wording rules** (the prompts in `server/system/ai/index.ts`): an ingredient **name** carries its intrinsic *variety/type/grade* in parentheses (`Pommes de terre (Marbella)`, `Farine (T45)`) — only *transient* preparation (peeled, sliced) goes in the steps. A proposal must apply a remark's concrete value change into the right structured field (a Thermomix time/temperature/speed in the step `settings`, a duration in the dish step text, a quantity on the ingredient) and summarise each change in `changeSummary` as `old → new` — the arrow being U+2192 and nothing else, a substitution written like a value change (`Citrons jaunes 2-3 pièces → Pomelo 1 pièce`) — several changes joined by `, ` (`Bouillon 50 → 40 cl, cuisson 3 h 30 → 4 h`). Rendered verbatim as the proposal card's title, so the prompt must name the arrow character explicitly: told only "a comma-separated list of deltas", the model has answered with the comma as the separator *inside* a change.
- **Style rules that bite here** (see [code-style](docs/code-style.md)): no `null` in the domain (absence is `field?: T` / `undefined`, converted only at the GraphQL, Firestore and AI boundaries); arrays and their items are never optional (`[T!]!` in GraphQL, `{}` for a plain step's `ThermomixStep.settings`); enum/union values are English technical symbols (`dish`, `starter`, `ai-proposal`) that the app translates.

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
- **Dated note (2026-07-20)**: production Firestore now holds real data (the recipes cooked on the device) — **every schema-shape change needs its migration**, the pre-release shortcut is over; see [docs/migrations.md](docs/migrations.md)

## iOS Patterns (SwiftUI)

> Full iOS guide: [docs/ios-guide.md](docs/ios-guide.md) — project wiring; the portable SwiftUI
> rules (reusable in any project) live in [docs/swiftui-best-practices.md](docs/swiftui-best-practices.md).

- Target: iOS 26.0, Swift 6 (strict concurrency). Xcode project `ios/Shuhari.xcodeproj`, scheme `Shuhari`, bundle id `com.polyforms.shuhari.app`, team `46C337T7YN`.
- Architecture: MVVM with `@Observable`. `@MainActor` on ViewModels, `Sendable` on model types. Apollo iOS codegen for typed GraphQL operations.
- Style: **Liquid Glass** = native iOS 26 components (no custom re-skins).
- Feature structure: `ios/Shuhari/Features/{Feature}/` with `pages/`, `organisms/`, `molecules/` subdirectories; shared atoms in `ios/Shuhari/Shared/Components/`.
- **Primitive-first views**: leaf views receive only primitives (`String`, `Int`, `Bool`, `Date?`, enums, closures) — never domain structs. Use nested `Item` structs for 5+ parameters.
- **Previews as Storybook**: every component below page level must be previewable without a running server.
- **A CTA that hits the network shows it**: `ActionIcon` swaps the button's SF Symbol for a spinner (from `ErrorPresenter.isRunning`), AI waits own the screen with `AIThinkingCard`, and one-way actions (delete) go optimistic in the background. Never `.disabled(...)` alone. Rule: [docs/swiftui-best-practices.md](docs/swiftui-best-practices.md) (project-agnostic), wiring: [docs/ios-guide.md](docs/ios-guide.md#cta--network--never-a-silent-wait).
- **Pages = coordinators**: handle loading, error, sheets, toolbar, API calls; map domain models to primitives for children. **Organisms** can accept domain structs when they break them down into primitives for child sections.
- Xcode uses `fileSystemSynchronizedGroups` (no need to manually add files). `DEVELOPER_DIR` is required because `xcode-select` points to CommandLineTools.
- Auth: Firebase Auth + Sign in with Apple (mono-user, but real auth).

## App Store Distribution

Build with the latest **final** Xcode — never a beta/RC, and never an older release once a newer final ships. Both trigger **ITMS-90111** (Unsupported SDK or Xcode version) on upload.

**Release flow** (the changelog is written here, not at push time), in order:
1. Write the release notes in English under `## Unreleased` in `CHANGELOG.md` (grouped `### New` / `### Fixes`), then the French translation under `## Unreleased` in `CHANGELOG.fr.md`. Rename the `## Unreleased` heading in **both** files to `## <version> (<YYYY.MM.DD>)` (e.g. `## 1.0 (2026.08.01)`) — matching the version you are about to upload. There is no CI date-stamp; versioning is manual.
2. **Push `main`** — the Deploy workflow regenerates the served changelog asset (`server/system/changelog-content.ts`) from `CHANGELOG.fr.md` via `bun run generate:assets`. This step is **required for the in-app changelog**: the notes only reach the app once a `main` deploy has rebuilt the asset. The app shows the version as the row title and the date on the right; a plain `## Unreleased` would display literally as "Unreleased", so make sure it was versioned in step 1.
3. Archive, export and upload to App Store Connect (see below), bumping `CURRENT_PROJECT_VERSION` in `project.pbxproj`.

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
- **After finishing any iOS task**, build and launch the app in the simulator on your own — do not ask first. When the task touched UI, launch straight into the affected screen with DebugGallery (`xcrun simctl launch booted com.polyforms.shuhari.app -gallery <screen>`) and screenshot it to verify the change visually before reporting. Screens = the `switch` cases in `ios/Shuhari/Shared/DebugGallery.swift`; add a case if the touched screen has none. See [docs/ios-guide.md](docs/ios-guide.md#previews-as-a-storybook--debuggallery). Distinct from the physical-device install below, which still requires an explicit yes.

## iOS Physical Device Install

- After finishing a task (especially one touching iOS), **offer** to install it on the physical iPhone "TiPhone junior" (UDID `00008130-000A2068029A001C`, automatic dev signing, team `46C337T7YN`). Never install automatically — ask first, run only after a yes.
- On a yes, run `scripts/install-device.sh` to build → install → launch.
- The device must be connected, unlocked, and trusted. Relay the raw `xcodebuild`/`devicectl` output — don't claim success without it.
