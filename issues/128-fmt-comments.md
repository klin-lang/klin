# 128 — `klin fmt` keeps `//` comments

**Status:** ✅ done
**Depends on:** [033](033-gofmt-style.md)

## Problem

The lexer treated `//` as whitespace. `klin fmt` reprints from the AST,
so comments vanished. The language was fine; only the formatter dropped
them. 033 listed preservation as later.

## Done

- [x] Lexer collects `SourceComment` (not a token; parser unchanged)
- [x] `formatSource` replays leading / trailing / header / footer `//`
- [x] Golden `test/fmt_comments.kl` + idempotence
- [x] [docs/05-fmt.md](../docs/05-fmt.md)

## Out of scope

- `/* */` (not in the language)
- Formatting `$fn` files before expand
