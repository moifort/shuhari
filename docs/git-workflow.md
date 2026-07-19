# Git Workflow — Commits & Push

The rules for how work is checkpointed locally and shipped to the remote. CLAUDE.md's
*Development Workflow* section is the quick reference; this doc is the full spec.

## Language

Everything in git history is **English**: commit messages, branch names, PR text. `CHANGELOG.md`
is English too — it is the source of truth. The only French in the repo is user-facing copy
(`CHANGELOG.fr.md`, the copy served to the app, and the iOS app's on-screen text). Never mix
languages inside a commit message.

## Commit cadence — one task, one commit

- **Commit freely, per completed task.** As soon as a task is finished, commit it — no need to
  ask the user, and no need to ask about grouping. You decide the boundaries.
- **One task = one commit.** Do not bundle several independent features/fixes into a single
  commit. A self-contained commit per task is what makes a rollback a clean `git revert`
  (see *Rollback* below). Bundling forces hand-unpicking later.
- **Verify before committing.** Build must be green first: backend `bun tsc --noEmit` (run
  `bun run prepare` first if routes changed) and/or the `xcodebuild` iOS build, depending on
  what was touched. Run tests when the change has a testable surface.
- **Review before committing.** After each completed task, run an expert code review
  (`superpowers:requesting-code-review`) and address its actionable findings before the commit.
- **Each commit must build.** When a task spans multiple files, stage them all together — never
  land a commit that references code deleted/added in a different, uncommitted change.

## Commit message format

Conventional Commits, imperative mood, scoped by area:

```
type(scope): short summary in the imperative

Optional body: what changed and why, wrapped ~72 cols.

Co-Authored-By: Claude <noreply@anthropic.com>
```

- **type**: `feat`, `fix`, `refactor`, `docs`, `chore`, `test`, `revert`, …
- **scope**: the touched area — `ios`, `server`, `infra`, `changelog`, a domain name, etc.
- Always end with the `Co-Authored-By:` trailer.

## Branching

Commit on the working branch (usually **`main`**) — this project commits freely to `main` by
convention, so the generic "branch first before committing" rule does **not** apply here. Only
branch when the user asks for a branch/PR.

## Rollback

Because each task is its own commit, rolling back a task is a **`git revert <sha>`** of that
task's commit (or an interactive drop while the commits are still local and unpushed). If a
past commit accidentally bundled several tasks, a clean revert is impossible — remove the parts
by hand, then commit the removal; that pain is exactly why one-task-one-commit matters.

## Never push until asked

- **Never push until the user explicitly says "push".** Commits accumulate locally; pushing is
  user-gated. Approval to commit is never approval to push.

## Push protocol (only when the user says "push")

1. **Re-analyze & reshape the pending commits.** List them with
   `git log origin/<branch>..HEAD`, then rewrite the local sequence into clean, bisectable
   units before anything leaves the machine:
   - Squash/regroup related commits into coherent units.
   - Rewrite messages for clarity.
   - **Elide undone work** — a feature commit plus its later revert should collapse and leave
     **no trace** on the remote, not ship as two commits.
2. **Biome autofix.** Run `bun run lint:fix` (`bunx biome check --write`) to correct every
   auto-fixable formatting/syntax issue across the repo — including vendored/generated files like
   asset-catalog `Contents.json`, which CI's `bunx biome check` lints too. Then run `bun run lint`
   to confirm it's clean, and commit any changes. This is what keeps the Unit Tests job (which
   runs `biome check`) green — a local `bun test` alone does **not** cover Biome.
3. **README** (`README.md`): update the features / tech-stack sections if the pushed work
   changed them.
4. **iOS GraphQL API** (only if the GraphQL schema changed): run `bun run generate:graphql`,
   then `bun run generate:ios`, and commit the regenerated `shared/schema.graphql`
   and the generated Apollo operations so the app's typed operations stay in sync with the
   deployed schema.
5. **Push.**
6. **Analyze the CI.** A push to `main` fires two workflows — **Unit Tests** (`bun tsc`) and
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
