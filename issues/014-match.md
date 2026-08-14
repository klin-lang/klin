# 014 — `match` (default break)

**Status:** ✅ complete
**Depends on:** 003

> **Historical note.** An early, complete `match` implementation was built on
> branch `issue-014-match` (2026-07-30), but was never merged to
> `main` — it was built against an old frontend and today conflicts in the core
> (`lexer`/`parser`/`ast`/`checker`/`emit_c`). It served as a **design
> reference** (syntax, tests, docs); the proper implementation was built from scratch
> on a fresh branch from `origin/main`. The old branch can be deleted.

## Scope

- keyword `match` (not `switch`)
- **default break** — no fallthrough, no `fallthrough` keyword
- grouping: `1, 2, 3`
- inclusive range: `4..=10`
- statement form and expression form

## Syntax

Without assignment (statement):

```
match x {
    1, 2, 3 {
        puts("abc")
    }
    4..=10 {
        puts("def")
    }
    else {
        puts("other")
    }
}
```

With assignment (expression):

```
let a = match x {
    1, 2, 3 { 10 }
    4..=10  { 20 }
    else    { 30 }
}
```

## Decisions

- Emission: chain of `if` / `else if` (subject once into a temp variable)
- Patterns `>= 4` / `when` guards — later → [084](084-match-when-rel.md)
- `else` required in expression form; optional in statement form
- Subject must be integral (`i8`…`u64`, `int`); `f64` / structs —
  checker error
- Expression form only as `let` initializer or right-hand side of
  assignment (lowers to statement, not to a C expression)
- `match { … else { error(n) } } or { … }` — [132](132-match-else-or.md)
  (`error` as a `!T` value; both the function form and the local form)
- Arms return a value, not a string — `str` is not yet a first-class type
  (example with `"abc"` from early sketch would fail the checker
  outside `match` too)

Details: [docs/15-match.md](../docs/15-match.md).

## Completion criteria

- [x] `match` as statement — golden test (`test/match_stmt.kl`)
- [x] `let a = match …` — golden test (`test/match_expr.kl`)
- [x] no fallthrough between arms (emission without `switch`/`case`)
- [x] checker errors: `else` not at end, missing `else` in expression,
      non-integral subject, `match` as expression in wrong position
- [x] `klin fmt` (`test/fmt_match.kl`), example
      [`examples/match.kl`](../examples/match.kl)
