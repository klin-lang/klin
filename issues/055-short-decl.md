# 055 — `:=` shorthand (= `let mut`)

**Status:** ✅ done
**Depends on:** 002

## Description

Go/V-style syntax: `name := expr` as syntactic sugar for
`let mut name = expr`.

```
x := 1          // ≡ let mut x = 1
x = x + 1       // assignment (unchanged)
```

`let` / `let mut` remain. `:=` does **not** introduce an immutable variable
(unlike V, where `:=` is immutable by default and you must add `mut`).
In Klin default immutability is `let`; `:=` is solely a shorthand for a mutable declaration.

## Scope

- `:=` token in lexer
- `name := expr` → `LetStmt(isMut: true, …)` (initializer required)
- in C-`for`: `for i := 0; …` declares (see [151](151-for-c-init-decl-vs-assign.md);
  `for i = 0` is assignment to an existing mut, not a second declaration form)
- `klin fmt` preserves `:=` (does not expand to `let mut`)
- no type annotation with `:=` in MVP (`x: i32 := 1` — out of scope;
  use `let mut x: i32 = 1`)

## Out of scope

- `:=` in destructuring / multi-assign
- overloading `:=` on user types
- changing semantics of existing `let` / `let mut`

## Completion criteria

- [x] golden test: `:=` + mutation works, emission without `mut` in C
- [x] `klin fmt` preserves `:=`
- [x] frontend catches `:=` without RHS
- [x] entry in `issues/sorted.md` + short mention in README / note
