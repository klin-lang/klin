---
name: rmain
description: >
  Shorthand "rmain" = rebase the current feature/fix branch onto origin/main.
  Use when the user writes "rmain", "rebase on main", "rebase onto main",
  or when an open PR branch must catch up with merged main.
---

# rmain — rebase onto `main`

When `rmain` (or "rebase on main" / "rebase onto main") appears, stay on the
**current** feature/fix branch and rebase it onto the latest `origin/main`:

```sh
git fetch origin main
git rebase origin/main
```

If the branch already has a remote (typical after push + PR):

```sh
git push --force-with-lease
```

Then update the existing PR (`ManagePullRequest` `update_pr`) if one exists.

## Rules

- This is a **feature-branch** operation. Do **not** run `rmain` while on
  `main` or `develop`. Those get `pmain` (checkout + pull), never a rebase.
- Do **not** `git checkout main` as part of `rmain`. Fetch `origin/main` and
  rebase onto that ref. Local `main` may be stale; `origin/main` is the base.
- Refuse a dirty tree: commit or stash first. Do not rebase uncommitted work.
- Network: on `git fetch` / `git push` failures, retry with backoff
  (4s, 8s, 16s, 32s).
- Conflicts: resolve them, `git rebase --continue`. Abort only if stuck, and
  say so. Do not invent a merge commit instead of the rebase.
- After a successful rebase of a published branch, push with
  `--force-with-lease` (history rewrote). Never `--force`.
- Never rebase `main` / `develop` themselves. Never commit on them.

`pmain` updates local `main`. `rmain` moves the **current** branch onto
that `main`. They are not interchangeable.

## When to use

- An open PR is behind `main` after other PRs merged.
- The user asks explicitly ("rmain" / "rebase on main" / "rebase onto main").
- Before more work on a long-lived feature branch that drifted from `main`.
