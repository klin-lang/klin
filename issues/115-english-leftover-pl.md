# 115 — Leftover Polish after 025 / 082

**Status:** ✅ done
**Depends on:** [025](025-english-project.md), [082](082-english-issues-docs.md)

## Goal

Finish the English migration. 025 moved CLI/compiler text; 082 moved
`docs/` + `issues/` and renamed Polish slugs. A few Polish strings were
left behind in toolchain files and in a handful of diagnostics.

## Inventory (no Polish path names)

Folder and file slugs are already English (082). Nothing to `git mv`.

| Place | What was Polish |
|---|---|
| `Taskfile.yml` | comments + `desc:` strings |
| `.gitignore` | comments |
| `README.md` | leftover “(Polish)” on the docs/roadmap links |
| `lib/parser.dart` | `oczekiwano …` expect-messages (and two mixed EN+PL) |
| `lib/lexer.dart` | unknown escape-sequence message |
| `lib/checker.dart` | three leftover `nieznana` / `wymaga typu` messages |
| `lib/ast.dart` | one `lub` comment |
| `test/pipeline_*_test.dart` | assertion on `ucieczki` |

## Done

- [x] Translate Taskfile / gitignore / README leftover
- [x] Translate leftover diagnostics to the existing English wording
  (`expected …`, `unknown function`, `unknown variable`,
  `unknown escape sequence`)
- [x] Update the one test that pinned a Polish substring
- [x] Note the sweep on 025 / 082

## Out of scope

- Bilingual PL+EN mirror
- Renaming paths (already English)
- Mentions of Polish as a *language* in `docs/03-name-license.md`
  (the name “Klin” is meant to be pronounceable in Polish and English)

## Criteria

`rg` for Polish diacritics and the leftover stems (`oczekiwano`,
`nieznana`, `ucieczki`, `inicjalizatora`) is empty outside this issue
and the 025/082 historical notes.
