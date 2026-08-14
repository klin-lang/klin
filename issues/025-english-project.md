# 025 — English project (except pl-PL)

**Status:** ✅ done (PL exception for design/roadmap **superseded by [082](082-english-issues-docs.md)**)
**Depends on:** —

## Goal

Review the repo and move to English **everything except the Polish corpus**.

## PL stayed (pl-PL) — superseded by 082

Originally `issues/` and `note/` (later `docs/`) were the official PL corpus
(roadmap, decisions, architecture) and were not translated in 025.
**[082](082-english-issues-docs.md)** completed the migration: `note/` → `docs/`,
and both `docs/` and `issues/` are English (including English file slugs).

## Moved to English (025)

- [x] frontend / CLI messages (`lib/*`, `bin/*`, `svd2klin`)
- [x] tests: assertions on error text, `test(...)` descriptions, comments in `test/`
- [x] `README.md`, `pubspec.yaml` description, CLI help
- [x] `CLAUDE.md` / agent rules: EN
- [x] compiler code comments (eventually all EN; when editing a file — EN)
- [x] leftover PL after the first pass — [115](115-english-leftover-pl.md)
  (Taskfile / gitignore / a few parser·lexer·checker diagnostics)

## Criteria

Contributor without Polish can handle build/test/diagnostics **and** read
design (`docs/`) + roadmap (`issues/`) — see 082.

