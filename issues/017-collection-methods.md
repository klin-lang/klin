# 017 — Collection methods (`map` / `filter` / …)

**Status:** ✅
**Depends on:** 007 (slice ✅); fn-pointer (phase 2 ✅); layer 2: `Allocator` ([057](057-allocator.md) ✅)

Note: [16-slice.md](../docs/16-slice.md) · fn-ptr: [13-fn-ptr.md](../docs/13-fn-ptr.md) ·
allocator: [14-allocator.md](../docs/14-allocator.md)

## Context

In JS: `arr.map(…)`, `filter`, `reduce`, `find`, `forEach`. Convenient, but in
systems languages it is easy to get hidden allocation and hidden cost (callback, heap).

## API decisions

### Principle

No bare `xs.map(f)` in JS style. Every operation that produces data either
takes a ready buffer, or (layer 2) an explicit `Allocator`. `defer` always on
the caller side — the API never registers freeing or autofree.

```
// OK — zero allocation (monomorphic names via $fn)
let n = slice.filter_into_i32(xs, dst, pred) or { 0 }
let y = slice.reduce_i32(xs, 0, add)

// OK — cost is visible (separate module so `import slice` does not pull heap)
let mut out = slice_alloc.map_alloc_i32(&a, xs, f) or { mem.empty_i32() }
defer mem.free_i32(&a, out)
```

Without generics in grammar: `each_i32` / `map_into_u8` (instances in
[`stdlib/slice.kl`](../stdlib/slice.kl)); `map_alloc_i32` in
[`stdlib/slice_alloc.kl`](../stdlib/slice_alloc.kl). Element types: `i32`, `u8`,
`i64`, `f64` (for `slice_alloc` allocator from [`stdlib/mem.kl`](../stdlib/mem.kl)).

### Naming

- Zero allocation, short: `each`, `index_of`, `any`, `all`, `count`, `reduce`
  (`index_of` returns index, not element — do not confuse with JS `find`)
- Production into buffer: always `_into` suffix (`map_into`, `filter_into`)
- Allocation: always `_alloc` suffix (`map_alloc`, `filter_alloc`) — layer 2
- Avoid bare `map` / `filter` without suffix

### Call form (not methods on `[]T`)

Layer 0+1 — `slice` module (no `mem` / no `malloc` in emission):

```
import slice
slice.map_into_i32(xs, dst, f)
```

Layer 2 — separate `slice_alloc` module (imports `mem` + `slice`). Emit does not
remove unused `pub`, so keeping `*_alloc` in `slice.kl` would pull
heap on every `import slice` (freestanding / prime rule).

```
import mem
import slice_alloc
slice_alloc.map_alloc_i32(&a, xs, f)
```

### Ownership — no `using` (C#)

| Variant | What is created | Who frees |
|---|---|---|
| `*_into(dst, …)` | nothing new — write to caller buffer | nobody (caller owns `dst`) |
| `*_alloc(a, …)` | **new** buffer | caller: `defer mem.free_i32(&a, out)` |

### Callback

Function pointers without capture ([docs/13-fn-ptr.md](../docs/13-fn-ptr.md)).

Write via `dst[i]` on slice: allowed (slice header is by value; element memory
shared with caller — like Go).

## Layer 0 + 1 (MVP) — ✅

| Function | Allocation | Notes |
|---|---|---|
| `each` | none | side effect |
| `index_of` | none | returns index; if missing: **`-1`** |
| `any` / `all` / `count` | none | |
| `reduce` | none | accumulator + function |
| `map_into` | none | requires `dst.len == xs.len`; returns `!i32` (`0` / `error(1)`) |
| `filter_into` | none | requires `dst.len >= xs.len`; returns `!i32` (count written / `error(1)`) |
| `copy_into` | none | `dst.len >= xs.len`; returns `!i32` = `xs.len` |
| `reverse_into` | none | same; copies reversed |
| `sum` / `product` | none | numeric; empty → `0` / `1` |
| `min` / `max` | none | numeric; `!T`, empty → `error(1)` |
| `contains` | none | numeric; `bool` (`==`) |

Template split: general (non-arithmetic) in `$fn slice_ops`, numeric
(`+`/`*`/`<`/`==`) in `$fn slice_num_ops` — so the general template also works for
non-numeric types.

Outside MVP: `flatMap`, `groupBy`, lazy iterators (struct + `next()`), sort with
closure comparator.

## Layer 2 (`*_alloc`) — ✅

Type `Allocator`: [`stdlib/mem`](../stdlib/mem.kl)
([docs/14-allocator.md](../docs/14-allocator.md)).

Module [`stdlib/slice_alloc.kl`](../stdlib/slice_alloc.kl):

- `map_alloc_i32` / `map_alloc_u8(a, xs, f): ![]T` — `alloc(xs.len)` + mapping
- `filter_alloc_i32` / `filter_alloc_u8(a, xs, pred): ![]T` — two passes
  (`count` → `alloc(n)` → copy)
- Allocator: `*mut mem.Allocator`; `mem.alloc_*` errors via `!` / `or`
- Caller: `defer mem.free_i32(&a, out)` (API does not register `defer`)

## Phases

1. **Docs** — API design. ✅
2. **Fn-pointer** — `fn(...): T`. ✅
3. **stdlib `slice` layer 0+1** — ✅ ([`stdlib/slice.kl`](../stdlib/slice.kl))
4. **`Allocator`** ([057](057-allocator.md) ✅) + layer 2 `*_alloc` — ✅
   ([`stdlib/slice_alloc.kl`](../stdlib/slice_alloc.kl))

Golden: `test/fn_ptr.kl`, `test/slice_ops.kl`, `test/slice_alloc_ops.kl`.  
Examples: `examples/fn_ptr.kl`, `examples/slice_ops.kl`,
`examples/slice_alloc_demo.kl`.

`map_into_*` / `filter_into_*` return `!i32` (Klin has no `!void`): success
`0` / element count; buffer length error → `error(1)`.

## Possible further extensions (ideas, not implemented)

- `find_$T` (returns element, not index — like JS `find`), `zip_into`, `chunk`,
  `dedup_into`.
- `sort` in-place on `[]T` with fn-ptr comparator.
- `flatMap` / `groupBy` (require allocation / nesting).
- more element types: `f32`, `i16`, `i8`, `u16`, `u32`, `u64`, `bool` (for
  `any`/`all`) — in `slice`; in `slice_alloc` require `mem` allocator for the
  type.

Note (technical debt): `min`/`max` in `slice_num_ops` have conditions written so
they do not end with a bare name before `{` — because `name {` in a condition is
mis-parsed as a struct literal. Worth fixing this parser limitation
(`if`/`while` conditions should suppress struct literals, like `match`).

## Non-goals

- Copying JS 1:1 (`map` always new GC array).
- `using` / RAII / autofree of result.
- Closures (D7), core generics (034).
- Methods on `[]T` before slice receiver decision.
- DCE of unused `pub` in emit (hence separate `slice_alloc` module).

## Completion criteria

### Docs phase

- [x] API design / names / ownership / phases written in this issue

### Fn-pointer phase

- [x] Type `fn(...): T` + pass / call
- [x] Golden + example

### Layer 0+1 phase

- [x] `slice` module with MVP functions (`i32`, `u8`)
- [x] Golden tests
- [x] No `malloc` in emission (loop like hand-written C)

### Layer 2 phase

- [x] `map_alloc` / `filter_alloc` in `slice_alloc` + `defer mem.free_*` documentation
- [x] Golden tests with explicit `Allocator`
