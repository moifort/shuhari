# Collaboration — How to Work With Claude on This Repo

The working agreement between Thibaut and Claude. These rules travel with the repo — they are
the single source for collaboration conventions, replacing any machine-local assistant memory.

## Docs are the spec

- The guides in `docs/` are the **source of truth** for the project's practices. "Apply the
  practices" means make the code conform to them, not invent new rules. When code diverges from
  a doc, change the **code**, not the doc (exception: an explicit user request to update a
  specific doc).
- **`docs/code-style.md` is law and must never be modified.** If it ends up with a stale
  reference, flag it to the user instead of editing it.
- **Codify corrections.** When the user corrects an architecture/style point in conversation
  (e.g. "a domain error should just be a const"), two things must happen in the same task:
  1. Apply the correction **repo-wide** — migrate the existing code, not just the new feature.
  2. Write the rule into the matching `docs/` guide, preferring the most stripped-down form of
     the pattern. A correction that stays conversational is lost for future sessions.

## Conversation vs execution

- In design/architecture discussions, phrases like "je veux faire X" express **design intent**,
  not a green light to implement. Keep answering with analysis, trees, and trade-offs; writing
  a plan file to capture a decision is fine, but wait for an explicit implementation request
  ("vas-y", "implémente", "lance") before touching code.
- **Every plan opens with a domain-impact summary**: a "Domaines impactés" block with three
  lines — Créés / Modifiés / Supprimés — listing the affected domains (`server/domain/*`, iOS
  features), before the detailed body. The blast radius is how plans are scanned.

## Ops autonomy

For infra/setup/ops tasks, **do everything technically possible yourself** rather than handing
the user a checklist: create GitHub secrets via `gh secret set`, write workflows, commit. Probe
before assuming a step is credential-gated (`gh auth status`, local files — e.g. `gh auth token`
may already carry the needed scopes). Hand off only the steps that genuinely require the user's
external logins (Apple, etc.), as precise numbered instructions.

## Visual assets

Generate visual assets (app icons, illustrations) with **Nano Banana Pro** (Gemini image model)
through the Gemini API — never hand-authored SVG rasterized afterwards. The key is already in
`.env` as `NITRO_GOOGLE_API_KEY`; call `generateContent` with `responseModalities: ["IMAGE"]`,
iterate by viewing the output, resize with `sips`.

## No internal memory

Claude must **not** use its machine-local persistent memory for this project. Every
collaboration learning, preference, or project note is codified in this file or in the relevant
`docs/` guide — so any machine that clones the repo has the full working context.

## External references

`/Users/thibaut/Code/vinarium` (sibling repo) shares shuhari's exact stack and conventions
(Bun + Nitro + Pothos + Firestore repositories, SwiftUI + Apollo codegen, same DDD layout).
When a feature exists in vinarium, **replicate its pattern rather than inventing one**:

- Cursor pagination: `beverage/infrastructure/repository.ts` `findPage` (`where` + `orderBy` +
  `startAfter(docSnapshot)` + `limit(n+1)` → `hasMore`), hand-rolled page type
  `{ items, hasMore, totalCount }` (no Relay connection), sort/order GraphQL enums.
- Firestore composite indexes declared in `firestore.indexes.json`, provisioned by
  `infra/firestore.tf` (`jsondecode` fan-out) — shuhari has the identical mechanism;
  `terraform apply` is manual, outside CI.
- iOS infinite scroll: `WineListViewModel` (accumulated items, `loadMore` with cursor,
  `prefetchIfNeeded`, `generation` token against stale responses, `scheduleReload` on filter
  `didSet`) + `Shared/Components/LoadMoreRow.swift` (spinner → retry button).
- Firestore `orderBy` silently drops docs missing the sorted field — only sort/cursor on
  fields required on every doc.

## Project status (dated notes)

Temporal facts — **delete each note once it no longer holds.**

- **2026-07 — production Firestore is empty.** The app is pre-first-release; no real data
  exists. Schema-shape refactors therefore need **no migration** while this holds (see the
  note in [migrations.md](migrations.md)). Obsolete as soon as real data lands.
- **2026-07 — Sentry migration tail.** The `fixme-nitro` → `@sentry/node` migration is almost
  done: the server plugin (`server/plugins/01-sentry.ts`) and the infra rename
  (`infra/variables.tf` / `infra/secrets.tf` use `sentry_dsn`) are shipped, but
  `.github/workflows/deploy.yml` still passes `fixme_dsn = secrets.FIXME_DSN`. Until the
  workflow passes `sentry_dsn` (and the GitHub secret is renamed accordingly), **Sentry
  reporting is OFF in prod**.
