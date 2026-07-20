# Git Best Practices

Portable rules — nothing here names this project. This repo's policy (which branch, whether pull
requests exist, what the push protocol runs) is in [git-workflow.md](git-workflow.md).

## One task, one commit

- **Commit each completed task**, as soon as it is done. Deciding the boundaries is part of doing
  the work, not a question to ask afterwards.
- **Never bundle several independent features or fixes** into one commit. A self-contained commit
  per task is what makes a rollback a clean `git revert`; a bundled commit has to be unpicked by
  hand.
- **Each commit must build on its own.** When a task spans several files, stage them together —
  never land a commit that references code added or deleted in a different, uncommitted change.

## Verify before committing, not after

The build must be green *before* the commit: type-check and build whatever the change touched, run
the tests when the change has a testable surface. A commit that doesn't build turns `git bisect`
into guesswork, and "I'll fix it in the next one" is how a red history starts.

Review your own diff before committing — the diff is what you are actually shipping, not what you
remember writing.

## Commit messages: Conventional Commits, imperative mood

```
type(scope): short summary in the imperative

Optional body: what changed and why, wrapped ~72 cols.
```

- **type**: `feat`, `fix`, `refactor`, `docs`, `chore`, `test`, `revert`, …
- **scope**: the touched area — a platform, a layer, a domain name.
- The summary says what the commit *does*, not what you did ("add the favourites lens", not "added").
- The body is for **why**, and for anything a reader six months out couldn't infer from the diff.

## History is written in one language

Commit messages and branch names use the project's technical language — never mixed inside a
message. Product copy in another language belongs in the files that hold copy, not in the history.

## Rollback is `revert`, not surgery

Because each task is its own commit, undoing a task is `git revert <sha>` (or dropping the commit
while it is still local and unpushed). Rewriting history that others may have pulled is not a
rollback strategy.

## Reshape local commits before they leave the machine

Local commits are a workspace; the remote is a record. Before pushing, rewrite the local sequence
into clean, bisectable units:

- squash or regroup related commits,
- rewrite unclear messages,
- **elide undone work** — a feature and its later revert collapse and leave no trace, rather than
  shipping as two commits that cancel out.

## Pushing is a separate, deliberate act

Approval to commit is never approval to push. Commits accumulate locally; the push happens when the
person owning the branch asks for it. And a push isn't finished when the command returns — it is
finished when CI is green. Watch the run rather than assuming.
