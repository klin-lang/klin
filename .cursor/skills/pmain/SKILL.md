---
name: pmain
description: >
  Shorthand "pmain" = sync local `main` with origin. Use when the user writes
  "pmain", "sync main", "pull main", or when `main` must be refreshed before
  creating a new feature/fix branch.
---

# pmain — sync / pull `main`

When `pmain` (or "sync main" / "pull main") appears, run:

```sh
git checkout main
git pull origin main
```

## Rules

- This is a `main`-only operation: switch to `main` and pull from `origin`.
- Do **not** commit on `main` (repo rule) — `pmain` is for updating only, not
  for work. Do real work on a new `cursor/<desc>-...` branch created from a
  fresh `main`.
- Network: on `git pull` failures, retry with backoff (4s, 8s, 16s, 32s).
- After `pmain`, usually: `git checkout -b cursor/<desc>-...`, then make changes.
- To catch an **open PR** up with `main`, use `rmain` (newest unmerged) or
  `rmain N` — not another `pmain`.

## When to use

- At the start of a task, before creating a branch (fresh base).
- After a PR is merged, to bring local `main` up to date.
- When the user asks explicitly ("pmain" / "sync main" / "pull main").
