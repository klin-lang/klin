# 003 — Control flow

**Status:** ✅ done
**Depends on:** 002

## Scope

`if` / `else`, `while`, `for`, `return`, `break`, `continue`.

Straightforward, because C has the same — mapping is nearly one-to-one.

## Decisions

- **`for` — both forms** (like V):
  - range: `for i in 0..<5 { ... }` (`..<` exclusive; `i` always mut)
  - C-style: `for i := 0; i < 5; i = i + 1 { ... }` (no parens; `:=` introduces mut `i`)
    — later clarified in [151](151-for-c-init-decl-vs-assign.md): `=` in init is assignment only
- **`while`** separately (we do not copy V's `for cond`)
- **`match`** — outside 003 criteria (`match`, default break, no fallthrough;
  not C-style `switch`); separate step — done in [014](014-match.md)
- **`goto`** — not in user syntax; codegen may use it internally (008)

## Completion criteria

- [x] fizzbuzz works
- [x] loop with `break` and `continue`
- [x] golden tests
