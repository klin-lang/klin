# 034 — Generic types in the language

**Status:** 💭 not now (staying with D3)
**Depends on:** D3 experience / [026](026-preprocessor.md); does not block main queue

## Verdict (after 017 / 057)

**We are not implementing generics in grammar.** Staying with **D3**
([docs/01-decisions.md](../docs/01-decisions.md)): monomorphization via `$fn`
before parse.

Full type system with `T` in symbol table (variant 3) is large frontend cost
with **the same** C emission — gain is mainly naming ergonomics, not execution
model. Prime rule requires monomorphization anyway.

After [017](017-collection-methods.md) / [057](057-allocator.md) `$fn` in stdlib
suffices: `slice` / `slice_alloc` (`_i32` / `_u8`), `mem.alloc_i32` /
`alloc_u8`. Pain is naming (`map_into_i32` vs `map_into[T]`), not
semantic. **Still do not promise** `a.alloc(T, n)`
([docs/14-allocator.md](../docs/14-allocator.md)).

## Context

D3: generics **not** in grammar — compile-time macros. MVP works
(`point_macro`, SVD fluent, slice helpers — [docs/16-slice.md](../docs/16-slice.md)).

## Variants (when we revisit)

1. **D3 only** — strengthen macros (better diagnostics, dedent/`fmt`, AST quoting).
2. **Thin generics layer** — sugar (`fn id[T](x: T): T`) expanding to
   same as `$fn` (checker sees `T`, emit like monomorphs). **Preferred**
   goal when reopening topic.
3. **Richer generics** — type parameters in symbol table, constraints;
   larger cost — do not plan by default.

No vtable / boxing by default; frontend catches errors before gcc sees `.c`.

## Criteria for reopening

Only when you collect **2–3 hard places** where `$fn` is clearly worse
— not "would be nicer":

1. container with methods (`Vec[T]`) hard as macro-expand alone
   (`HashMap` / [060](060-map-kv.md) is ❌ struck — hidden resize)
2. parameterized `Option`/`Result` in many APIs (today `!T` suffices)
3. diagnostics from expanded `$fn` really block users

Then plan **variant 2**, not variant 3.

## Decision checklist

- [x] Verdict: staying with D3; reopening topic = variant 2 after criteria above
- [x] Short addendum in D3 ([docs/01-decisions.md](../docs/01-decisions.md))
- [ ] Collect 2–3 hard `$fn` pain points (start condition for implementation — not now)
