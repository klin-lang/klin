# 033 — Go-style formatting (`gofmt`)

**Status:** ✅ done
**Depends on:** stable grammar (practically after 005+); does not block main queue

## Goal

One canonical Klin source style — like `gofmt` in Go: **few options,
always the same result**, so you can format automatically without debate
about tabs, braces, and line breaks.

## MVP (done)

- CLI: `klin fmt [-w] <file.kl…>` — default stdout, `-w` write in place
- `lib/fmt.dart`: lex → `parseUnit` → pretty-print (4 spaces, K&R, spaces around op)
- Declaration order preserved (`ModuleUnit.decls`)
- Style: [docs/05-fmt.md](../docs/05-fmt.md)
- Golden: `test/fmt_ugly.kl` → `test/fmt_ugly.fmt.kl` + idempotence

## Outside MVP (later)

- Formatting **macro bodies** / `--emit-pp` result (dedent + `fmt`)
- LSP / editor `formatDocument` → [086](086-lsp.md) (uses `formatSource`; comments follow)
- `klin fmt ./...` recursively

## Criteria

- [x] `klin fmt` on examples without `$` gives repeatable result
- [x] style document in `docs/05-fmt.md`
- [x] golden ugly → formatted
- [x] `//` comments preserved ([128](128-fmt-comments.md))
