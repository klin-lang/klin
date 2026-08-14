# 129 — Exhaustive `match` on enum

**Status:** ✅ done
**Depends on:** [072](072-enums.md), [014](014-match.md)

## What

The checker requires a `match` on an enum to cover every variant, or
to end in `else`. Missing a name is an error — a silent no-op was
hidden control flow.

An unguarded `Enum.Variant` (also in a comma group) covers that name.
`when` does not: the guard can fail. A runtime value of the same enum
does not cover a name. Integers stay open (statement `else` optional;
expression `else` still required).

`else` remains the hatch for a leftover after `cast` (`cast(Color, 99)`).
A complete enum `match` without `else` counts as returning on all
paths when every arm returns.

No new grammar. Emission is unchanged (`if` / `else if` chain).

## Done

- [x] Checker: enum coverage + `when` / runtime-value rules
- [x] Expression `match` may omit `else` when the enum is complete
- [x] Golden [`test/enum_match_exh.kl`](../test/enum_match_exh.kl)
- [x] [`docs/15-match.md`](../docs/15-match.md), [`docs/syntax.md`](../docs/syntax.md)

## Out of scope

- Dead-arm warnings (duplicate `Color.Red`)
- Exhaustiveness on integers
- Algebraic / payload enums
- `match { } or { }` / `error(n)` as a value — [132](132-match-else-or.md) ✅
