# Shuhari - Project Directives

守破離 — *Shu* (follow the rule), *Ha* (break it), *Ri* (transcend it). A culinary
experimentation notebook: import a recipe, cook a version, rate the attempt, let the AI
propose the next iteration, and open the best-rated version by default.

## Language

Everything versioned and technical is **English**: commits, code, comments, docs (incl. `CHANGELOG.md`), identifiers, file names, GraphQL descriptions, AI prompts, test names, iOS accessibility *identifiers*. Enum/union values are English technical symbols (`dish`, `starter`, `ai-proposal`) — the schema never speaks the user's language, the app translates. The **only** French in the repo: user-facing copy (`CHANGELOG.fr.md` + its generated asset `server/system/changelog-content.ts`, the iOS app's on-screen text and preview names), French data values quoted as examples in code/prompts, and the import fallback title. Never mix languages in a commit message or a comment. Control: `grep -rnP '[\x{00C0}-\x{00FF}]' server/` must only return those exceptions. Full rules: [docs/code-style.md](docs/code-style.md#language).

## Collaboration

> Full working agreement: [docs/collaboration.md](docs/collaboration.md) — read it at the start
> of any session. Key rules:

- **Docs are the spec**: align code to `docs/`, never the reverse; `docs/code-style.md` is law and is never edited to match the code (it changes only on an explicit user request). Corrections given in conversation are applied repo-wide **and** codified in the matching doc, in the same task.
- **Rules generic, wiring specific**: a practice that would hold in any codebase goes in a `*-best-practices.md` with neutral examples; how this repo implements it goes in the matching project guide, which links to the rule.
- **Work inline, never through subagents**: exploration, review, debugging and planning all happen in the main conversation — never `Task`/`Agent`, never a parallel-worker or subagent-driven skill, plan mode included.
- **Design talk is not a go**: in architecture discussions, "je veux faire X" is design intent — implement only on an explicit "vas-y" / "implémente" / "lance".
- **One checkout, no worktrees**: never `git worktree add`, never `EnterWorktree` — sessions share the primary checkout, so stage the explicit paths of your task (never `git add -A` / `commit -a`).
- **Every plan opens with a "Domaines impactés" block** (Créés / Modifiés / Supprimés) before the body.
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

> **Git commit & push rules live in [docs/git-workflow.md](docs/git-workflow.md)** (portable rules:
> [docs/git-best-practices.md](docs/git-best-practices.md)) — read it at the start of any coding
> session. This section is the quick reference.

1. Verify the build before committing: `bun tsc --noEmit` and/or the iOS `xcodebuild`, depending on what was touched (`bun run prepare` first if routes changed).
2. Review the diff yourself, **inline**, before committing — never through a subagent.
3. **Commit freely, one task = one commit**: commit each finished task without asking, never bundle tasks — a rollback is a clean `git revert`. English messages, Conventional Commits, `Co-Authored-By:` trailer.
4. **Close every task with the surfaces touched, then the diff size** ([docs/collaboration.md](docs/collaboration.md#closing-a-task-surfaces-then-diff-size)): one sentence on which of **the database**, **the backend** and **the iOS app** changed (the deployment blast radius), then `git show --stat HEAD | tail -1` and the lines added / removed — a refactor that only adds is a refactor that forgot to delete.
5. **Never push until the user explicitly says "push"**, and **never open a PR**: a push goes straight to `origin/main` (`git push origin HEAD:main`), whatever the working branch, following the [push protocol](docs/git-workflow.md#push-protocol-only-when-the-user-says-push) — reshape the pending commits, Biome autofix, regenerate the iOS GraphQL API if the schema changed, push, watch CI to green.
6. **Not at push time**: never touch `README.md` (updated on its own, when asked) or the changelogs — the changelog is written only during an [App Store release](docs/app-store-release.md).

## Backend Patterns (TypeScript / Nitro)

> Extended guides live in `docs/`, split in two: the **rules**, written project-agnostic —
> [ddd-best-practices](docs/ddd-best-practices.md), [graphql-best-practices](docs/graphql-best-practices.md),
> [code-style](docs/code-style.md), [branded-types](docs/branded-types.md),
> [error-handling](docs/error-handling.md) — and this repo's **wiring** —
> [architecture](docs/architecture.md), [domain-guide](docs/domain-guide.md),
> [graphql-patterns](docs/graphql-patterns.md), [business-rules](docs/business-rules.md),
> [migrations](docs/migrations.md), [readme-guide](docs/readme-guide.md),
> [collaboration](docs/collaboration.md). This section is the quick reference.

- **Stack**: Bun + Nitro 2.13 (`preset firebase`, gen 2, nodejs22, `europe-west3`) + Apollo Server 5 + Pothos 4 + firebase-admin (native Firestore) + Zod + ts-brand. DDD/CQRS strict. Biome (spaces 2, single quotes, no semicolons, width 100), `ts-pattern` (`match().exhaustive()`), `lodash-es`.
- **Domains**: `server/domain/{recipe,proposal,quota,entitlement,shared}` — `recipe`, `quota` and `entitlement` are the persisted domains; `proposal` is ephemeral (never stored) and the sole caller of `~/system/ai`, which it gates on the quota; system concerns in `server/system/`. Standard layout (`types.ts`, `primitives.ts`, `command.ts`, `query.ts`, `infrastructure/{repository,graphql/*}.ts`, optional `business-rules.ts` / `use-case.ts`): [docs/domain-guide.md](docs/domain-guide.md).
- **Branded types** (`ts-brand` + Zod constructors in `primitives.ts`: `RecipeId`, `VersionNumber`, `Rating`…); discriminated results for absence/errors (`'not-found' as const`) — no exceptions for control flow, no `null` in the domain (absence = `field?: T`, converted only at the GraphQL/Firestore/AI boundaries).
- **Storage: native Firestore**, only inside `infrastructure/repository.ts`, via the `server/utils/firestore.ts` helpers (`genericDataConverter`, `atomically`, `bulkSave`, `deleteInBatches`) and the per-request cache (`memoizedPerRequest`) — see [docs/architecture.md](docs/architecture.md#storage--native-firestore). Aggregate root `recipes` + append-only satellite `recipe-versions` keyed `${recipeId}_${number}`; standalone `ai-quotas` keyed `${userId}_${month}` and `entitlements` keyed by `userId`.
- **GraphQL** (single endpoint `POST /graphql`): satellite `RecipeType` fields resolve through the per-request `versionsByRecipe` loader — never a collection scan or one doc per parent (N+1); read budgets asserted in tests via `fake.reads`. See [docs/graphql-patterns.md](docs/graphql-patterns.md#satellite-loaders--the-n1-budget).
- **Naming / ubiquitous language**: function names ARE the business concept (`bestRating`, `versionToOpen` — never `computeX`, `handleX`); one business concept = one word at every layer (domain, GraphQL, iOS, tests). See [docs/domain-guide.md](docs/domain-guide.md#ubiquitous-language).
- **Tests**: `*.unit.test.ts` with `bun:test`; Firestore mocked via `server/test/fake-firestore.ts`, which records batches and read counts to assert atomicity and read budgets.

## Key Business Rules

> Full model narrative: [docs/business-rules.md](docs/business-rules.md) — read it before touching
> `recipe`, `proposal` or the AI prompts. The invariants in one glance:

- **Two recipe types** (`dish`, `thermomix`); a version's `content` is a discriminated union (`VersionContent = DishContent | ThermomixContent`) with the invariant `content.kind === recipe.type`, mirrored in GraphQL (union + `@oneOf` input). Ratings are `1..5`; the dish-category order IS the library's sort rank.
- **Linear lineage**: one chain `v1 → v2 → …`; `basedOn` = the version iterated from (absent on v1). No forks, no variations.
- **A version *is* an attempt**: `content` and lineage are immutable; the outcome and `tips` are overwritable. Fields with no value are **absent**, never `null`.
- **An attempt lands on the version it produces**: a bare rating → `recordAttempt` rewrites the version cooked in place; with remarks → the rating/remarks land on the accepted proposal's new version, and nothing is persisted if the proposal is refused.
- **Everything derived, no promotion**: `bestRating` and `versionToOpen` are computed in `recipe/business-rules.ts` from the cooked versions.
- **Improvement** (a requested change with no cook behind it) is the **sole** source of `toTest: true`; cooking the version drops it.
- **Tips** sit on the versioning envelope (never in `content`) and the lightbulb CTA rewrites them in place — no new version.
- **Freemium**: the notebook is unlimited, only the AI is metered — `free` gets 3 imports + 5 iterations per calendar month (proposal, improvement and tips share the iteration meter), `premium` is unlimited and alone may import from a URL. Checked before the call, recorded after it succeeds.
- **Premium is a verified App Store transaction, never a client claim**: `EntitlementQuery.planOf` is the single answer, derived from the `entitlements` document written by `syncEntitlement` (signature checked against Apple's roots) and by the `POST /apple/notifications` webhook. A purchase must carry the cook's derived `appAccountToken` or it is refused. `NITRO_PREMIUM_USER_IDS` remains a comp-account override. Setup: [docs/in-app-purchase.md](docs/in-app-purchase.md).
- **AI wording rules** (prompts in `server/system/ai/index.ts`): ingredient variety in the name's parentheses; `changeSummary` = `old → new` deltas (arrow U+2192, named explicitly in the prompt) joined by `, `.

## Database Migrations

- `server/system/migration/` — forward-only sequential migrations, no rollback, triggered by `POST /admin/migrate` (CI deploy / provisioning). When to migrate, how to write and register one: [docs/migrations.md](docs/migrations.md).
- **Dated note (2026-07-20)**: production Firestore now holds real data — **every schema-shape change needs its migration**, the pre-release shortcut is over.

## iOS Patterns (SwiftUI)

> Full iOS guide: [docs/ios-guide.md](docs/ios-guide.md) — project wiring; the portable SwiftUI
> rules live in [docs/swiftui-best-practices.md](docs/swiftui-best-practices.md).

- Target iOS 26.0, Swift 6 (strict concurrency). `ios/Shuhari.xcodeproj`, scheme `Shuhari`, bundle id `com.polyforms.shuhari.app`, team `46C337T7YN`. MVVM with `@Observable` (`@MainActor` ViewModels, `Sendable` models), Apollo iOS codegen, Firebase Auth + Sign in with Apple (mono-user, but real auth).
- Style: **Liquid Glass** = native iOS 26 components (no custom re-skins). Feature structure `Features/{Feature}/{pages,organisms,molecules}/`, shared atoms in `Shared/Components/`.
- **Primitive-first leaf views** (never domain structs; nested `Item` structs for 5+ parameters); **pages = coordinators** (loading, errors, sheets, API calls, mapping to primitives); **previews as Storybook** (everything below page level previewable offline); **a CTA that hits the network shows it** (`ActionIcon` spinner, `AIThinkingCard` for AI waits, optimistic deletes — never `.disabled(...)` alone).
- Xcode uses `fileSystemSynchronizedGroups` (no manual file adds). `DEVELOPER_DIR` is required because `xcode-select` points to CommandLineTools.

## App Store Distribution

Full release flow — changelog written at release time, latest **final** Xcode only (ITMS-90111), the beta-macOS `BuildMachineOSBuild` patch, `CURRENT_PROJECT_VERSION` bump: [docs/app-store-release.md](docs/app-store-release.md).

## Gemini API Key & Secrets

- The AI (import + proposals) is **Gemini 2.5 Flash** in `server/system/ai/`, key in `NITRO_GOOGLE_API_KEY`; `POST /admin/migrate` is gated by `NITRO_ADMIN_TOKEN`; `NITRO_SENTRY_DSN`, `NITRO_PREMIUM_USER_IDS` (comped Premium accounts), `NITRO_APPLE_APP_ID` and `NITRO_APPLE_ENVIRONMENT` (pins App Store signature checks, `Xcode` for the local StoreKit file) optional. Local `.env` (see `.env.example`); in production, GCP Secret Manager (project `shuhari-polyforms`). Never commit a key.

## iOS Simulator

- Device: iPhone 17, OS 26.2
- **After finishing any iOS task**, build and launch the app in the simulator on your own — do not ask first. When the task touched UI, launch straight into the affected screen with DebugGallery (`xcrun simctl launch booted com.polyforms.shuhari.app -gallery <screen>`) and screenshot it to verify the change visually before reporting. Screens = the `switch` cases in `ios/Shuhari/Shared/DebugGallery.swift`; add a case if the touched screen has none.

## iOS Physical Device Install

- After finishing a task (especially one touching iOS), **offer** to install it on the physical iPhone "TiPhone junior" (UDID `00008130-000A2068029A001C`, automatic dev signing, team `46C337T7YN`). Never install automatically — ask first, run only after a yes.
- On a yes, run `scripts/install-device.sh` to build → install → launch. The device must be connected, unlocked, and trusted. Relay the raw `xcodebuild`/`devicectl` output — don't claim success without it.
