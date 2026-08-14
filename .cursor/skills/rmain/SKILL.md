---
name: rmain
description: >
  Shorthand "rmain" = rebase an open PR onto origin/main. With no number,
  the newest unmerged PR; with a number ("rmain 267", "rmain #267"), that PR.
  Use when the user writes "rmain", "rebase on main", or "rebase onto main".
---

# rmain — rebase a PR onto `main`

`rmain` targets a **pull request**, not "whatever is checked out".

| Input | Which PR |
|---|---|
| `rmain` / "rebase on main" (no number) | Newest **unmerged** PR: first row of `gh pr list --state open` (newest first) |
| `rmain 267` / `rmain #267` | That PR number |

## Steps

1. Resolve the PR (read-only `gh`):

   ```sh
   # no number — newest open:
   gh pr list --state open --limit 1 --json number,title,headRefName,baseRefName,url,isDraft

   # given N:
   gh pr view N --json number,title,state,headRefName,baseRefName,url,isDraft
   ```

2. Refuse if there is no open PR (bare `rmain`), or if the numbered PR is
   merged / not found. Say which PR you picked (number, title, url).

3. Dirty tree on the current checkout: commit or stash first. Do not rebase
   uncommitted work.

4. Check out the PR head and rebase onto latest `origin/main`:

   ```sh
   git fetch origin main
   git fetch origin <headRefName>
   git checkout <headRefName>
   git rebase origin/main
   git push --force-with-lease
   ```

5. Update that PR (`ManagePullRequest` `update_pr` with `pr_url` or
   `branch_name`). Do not open a new PR.

## Rules

- Always a **PR** operation. Do not rebase "the current branch" unless it
  **is** the chosen PR's head. Do not invent a branch.
- Do **not** run this while intending to change `main` / `develop`. Those get
  `pmain` (checkout + pull), never a rebase. Never rebase `main` / `develop`.
- Do **not** `git checkout main` as part of `rmain`. Fetch `origin/main` and
  rebase the PR head onto that ref.
- Network: on `git fetch` / `git push` failures, retry with backoff
  (4s, 8s, 16s, 32s).
- Conflicts: resolve them, `git rebase --continue`. Abort only if stuck, and
  say so. Do not invent a merge commit instead of the rebase.
- After a successful rebase, push with `--force-with-lease` only. Never
  `--force`.
- Draft open PRs count as unmerged. Closed-unmerged: only if the user gave
  that number; say it is closed before rebasing.

`pmain` updates local `main`. `rmain` moves a **PR branch** onto that `main`.
They are not interchangeable.

## When to use

- An open PR is behind `main` after other PRs merged.
- The user asks explicitly (`rmain` / `rmain 267` / "rebase on main").
