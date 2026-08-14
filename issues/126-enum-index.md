# 126 — Enum as `[N]T` index

**Status:** ✅ done
**Depends on:** [072](072-enums.md), [007](007-pointers-arrays-slices.md)

## What

`table[Slot.B]` when `Slot` is an enum and `table` is a fixed array.
Emission is `table[slot]` — the enum is already a `typedef` to its
integer base. No map, no search, no hidden resize.

The checker proves every variant value is in `[0, N)`. Gaps are OK
if they still fit (`B = 2` in `[4]T`). `B = 5` in `[3]T` is an
error. Slices stay integer-only (`[]T` has no static `N`).

Integer indexes were already any integer prim (`i8`…`u64`,
`usize` / `isize`, `int`) — not only `i32`.

## Done

- [x] Checker: enum index + fit / slice errors
- [x] Golden [`test/enum_index.kl`](../test/enum_index.kl)
- [x] [`docs/syntax.md`](../docs/syntax.md), [`examples/enums.kl`](../examples/enums.kl)

## Out of scope

- `lookuptable` type / `map[K]V` ([060](060-map-kv.md) ❌)
- Enum index on slices
- Bounds checks at runtime
