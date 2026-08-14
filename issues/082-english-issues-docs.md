# 082 — English `docs/` + `issues/` (rename `note/` → `docs/`)

**Status:** ✅ done
**Depends on:** [025](025-english-project.md)
**Supersedes:** the PL-corpus exception in 025 for `note/` / `issues/`

## Goal

Make all design and roadmap documentation English and use the conventional
`docs/` directory name:

1. Rename `note/` → `docs/`
2. Translate all `docs/**` and `issues/**` (including `sorted.md`) to English
3. Update agent entrypoints (`CLAUDE.md`, skills) to the new paths
4. Rename Polish file slugs to English (numeric prefixes kept)

## Done

- [x] `git mv note → docs` (path references updated across the repo)
- [x] `docs/*.md` translated to English
- [x] `issues/*.md` + `sorted.md` translated to English
- [x] English filenames for formerly Polish slugs (e.g. `01-decisions.md`,
  `000-fundamental-decisions.md`)
- [x] `CLAUDE.md` points at `@docs/00-idea.md`, `@docs/01-decisions.md`,
  `@docs/02-architecture.md`
- [x] 025 marked as superseded for the PL exception

## Out of scope

- Bilingual PL+EN mirror
- Translating compiler/runtime code (already EN per 025; leftover
  diagnostics swept in [115](115-english-leftover-pl.md))

## Criteria

A contributor without Polish can read design (`docs/`) and roadmap (`issues/`)
end to end; there is no `note/` directory; agent rules use `docs/`.
