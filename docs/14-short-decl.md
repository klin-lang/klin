# `:=` shorthand (`let mut`)

Issue: [055](../issues/055-short-decl.md).
C-`for` init: [151](../issues/151-for-c-init-decl-vs-assign.md).

## Syntax

```
name := expr          // ≡ let mut name = expr
name = expr           // assignment (unchanged)
let name = expr       // immutable (unchanged)
let mut name = expr   // equivalent to `:=`
```

In C-`for` init the same distinction holds:

```
for i := 0; i < n; i = i + 1 { … }   // declare new mut i

i := 0
for i = 1; i < n; i = i + 1 { … }   // assign to existing i
```

If `i` is already in scope, `for i := …` is an error (no shadowing).

## Semantics

Like `let mut`: mutable local with initializer, type inference from
the right-hand side. In C emission there is no `mut` — a plain local remains.

## MVP limitations

- no type annotation with `:=` (`x: i32 := 1` — use `let mut x: i32 = 1`)
- `klin fmt` preserves `:=` / `=` (does not rewrite one into the other)

Example: [`examples/short_decl.kl`](../examples/short_decl.kl).
