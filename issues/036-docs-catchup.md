# 036 — Docs do not cover new Klin features

**Status:** ✅ done (catch-up in PR with 016)
**Depends on:** features ✅ on `main` (026–035) and 016

## Goal

User / contributor reads README + `docs/` + examples and sees full
picture of what already works — without rewriting `issues/` to EN.

## Scope

- README: toolchain (`run` / `fmt` / `test` / `--emit-c` / `--emit-pp`), macros,
  SVD fluent, interpolation
- `docs/06-cli.md` — subcommands and flags
- `docs/07-interpolation.md` — 016 syntax
- `stdlib/README.md` — `io` + `testing`
- `examples/README.md` — sync with files on disk

## Out of scope

- Translating `issues/` / `docs/` to EN (now tracked separately; see [082](082-english-issues-docs.md))
- Full language reference (a short tutorial is [116](116-docs-reorg.md) /
  [docs/guide.md](../docs/guide.md); this issue stays a feature catch-up)
