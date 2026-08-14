# `Allocator` — explicit heap (stdlib `mem`)

D1 model ([01-decisions.md](01-decisions.md)): manual + `defer` + allocator as
**explicit** argument. No GC / autofree / hidden `malloc` in the language core.

## MVP (`import mem`)

```klin
import mem

fn main() {
    let mut a = mem.heap()
    let mut buf = a.alloc_bytes(16) or {
        // n < 0 or OOM — empty slice (safe with free_*)
        mem.empty_u8()
    }
    defer a.free_bytes(buf)

    let mut xs = mem.alloc_i32(&a, 4) or { mem.empty_i32() }
    defer mem.free_i32(&a, xs)
}
```

| API | Notes |
|---|---|
| `mem.heap()` | host libc heap (empty `Allocator` for future arena/vtable) |
| `a.alloc_bytes(n)` / `a.free_bytes` | `![]u8`; methods on `mut Allocator` |
| `mem.alloc_i32` / `free_i32` (+ `u8`, `i64`, `f64`) | free functions with `*mut Allocator` |
| `mem.empty_u8` / `empty_i32` / `empty_i64` / `empty_f64` | `{NULL,0}` — fallback in `or`, safe with `free_*` |

- `n < 0` → `error(1)`; OOM → `error(2)`; `n == 0` → empty slice **without** `malloc`
- `free_*` on empty / NULL = no-op (`free(NULL)` in C)
- Emission: `klin_mem_alloc_*` / `klin_mem_free_*` (+ `#include <stdlib.h>`) only when
  program imports `mem` / calls those symbols
- Freestanding: **do not** `import mem`

Issue: [057](../issues/057-allocator.md). Example: [`examples/mem_heap.kl`](../examples/mem_heap.kl).

## Stdlib consumers

| Module | Notes |
|---|---|
| [`slice_alloc`](../stdlib/slice_alloc.kl) | `map_alloc_*` / `filter_alloc_*` — [017](../issues/017-collection-methods.md), [docs/16-slice.md](16-slice.md) |

Caller always: `defer mem.free_i32(&a, out)` (or `free_u8` / `free_bytes`).

## Do not promise in MVP / later

D1 sketch `a.alloc(u8, n)` requires a **type argument** in a method call.
Klin’s generic is `$fn` (expand before parse), not `[T]` in the compiler
([04-macros.md](04-macros.md), [034](../issues/034-generic-types.md)).
**Do not promise** `a.alloc(T, n)` as public API.

Today instead:

- bytes: `a.alloc_bytes(n)` / `a.free_bytes`
- typed: explicit `mem.alloc_i32` / `free_i32` (and `u8`) — possibly
  extended via `$fn` like in `slice` / `slice_alloc`, not via
  `alloc(T, n)` syntax

**Later (separate steps, not in 057):**

| Topic | Where |
|---|---|
| `a.alloc(T, n)` / sugar or generics | 034 / D3 |
| Arena + `deinit` (one `defer`) | follow-up after 057 |
| Vtable of allocators | follow-up (today heap + empty struct is enough) |
| GC / autofree / hidden `malloc` in core | **never** (overarching principle) |
