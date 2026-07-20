# Git Workflow — Commits & Push

This repo's git policy — how work is checkpointed locally and shipped to the remote. The portable
rules it builds on (one task one commit, verify before committing, Conventional Commits, revert over
surgery, reshape before pushing) are in [git-best-practices.md](./git-best-practices.md). CLAUDE.md's
*Development Workflow* section is the quick reference; this doc is the full spec.

## What the generic rules mean here

- **Language**: git history is **English** — commit messages and branch names, `CHANGELOG.md`
  included. The only French is user-facing copy (`CHANGELOG.fr.md`, the copy served to the app,
  the iOS app's on-screen text). Never mix languages inside a message.
- **Verify before committing**: backend `bun tsc --noEmit` (run `bun run prepare` first if routes
  changed) and/or the `xcodebuild` iOS build, depending on what was touched; tests when the change
  has a testable surface.
- **Review before committing**: read your own diff **inline**, in the session — never through a
  subagent (see [collaboration.md](./collaboration.md#work-inline-never-through-subagents)).
- **Commit trailer**: every message ends with the `Co-Authored-By:` trailer.
- **Scopes** used here: `ios`, `server`, `infra`, `changelog`, or a domain name.

## Branching

Commit on the working branch (usually **`main`**) — this project commits freely to `main` by
convention, so the generic "branch first before committing" rule does **not** apply here. Only
branch when the user asks for one.

## Never open a pull request

This is a solo project: CI (Unit Tests + Deploy) runs on `main` pushes only, so a pull request
is pure ceremony. **Never open one, never suggest one.** On "push", the work goes straight to
`origin/main` — even from a feature branch (see *Push protocol* below).

## Never push until asked

- **Never push until the user explicitly says "push".** Commits accumulate locally; pushing is
  user-gated. Approval to commit is never approval to push.

## Push protocol (only when the user says "push")

1. **Re-analyze & reshape the pending commits** — the generic rule
   ([reshape before pushing](./git-best-practices.md#reshape-local-commits-before-they-leave-the-machine)):
   list them with `git log origin/<branch>..HEAD`, squash/regroup, rewrite messages, and elide
   undone work so a feature plus its revert leaves no trace on the remote.
2. **Biome autofix.** Run `bun run lint:fix` (`bunx biome check --write`) to correct every
   auto-fixable formatting/syntax issue across the repo — including vendored/generated files like
   asset-catalog `Contents.json`, which CI's `bunx biome check` lints too. Then run `bun run lint`
   to confirm it's clean, and commit any changes. This is what keeps the Unit Tests job (which
   runs `biome check`) green — a local `bun test` alone does **not** cover Biome.
3. **iOS GraphQL API** (only if the GraphQL schema changed): run `bun run generate:graphql`,
   then `bun run generate:ios`, and commit the regenerated `shared/schema.graphql`
   and the generated Apollo operations so the app's typed operations stay in sync with the
   deployed schema.
4. **Push — straight to `origin/main`.** `git push origin HEAD:main` (fast-forward), whatever
   the working branch — never via a pull request. Realign local `main` afterwards.
5. **Analyze the CI.** A push to `main` fires two workflows — **Unit Tests** (`bun tsc`) and
   **Deploy**. Watch them through to completion rather than assuming green: `gh run watch`, or
   `gh run list --branch main --limit 5` then `gh run view <id> --log-failed` on any failure.
   The push isn't done until CI is green; if a job fails, report it and fix it (a follow-up
   commit + push), don't leave a red `main`.

## The changelog is a release-time activity — never at push time

A normal `main` push carries **no** changelog change. Do **not** touch `CHANGELOG.md` /
`CHANGELOG.fr.md` when pushing, and do not add `## Unreleased` entries per commit. The changelog
is written only at the moment of an iOS App Store release:

1. Write the notes in English under `## Unreleased` in `CHANGELOG.md` (grouped `### New` /
   `### Fixes`), then the French translation under `## Unreleased` in `CHANGELOG.fr.md`.
2. Rename the `## Unreleased` heading in **both** files to `## <version> (<YYYY.MM.DD>)` — there
   is no CI date-stamp, versioning is manual.
3. Push `main`: the Deploy workflow runs `bun run generate:assets`, which regenerates the served
   asset `server/system/changelog-content.ts` from `CHANGELOG.fr.md` (never edit that asset by
   hand). The notes reach the app only after this deploy.

See [App Store Distribution in CLAUDE.md](../CLAUDE.md#app-store-distribution) for the full
release flow.
