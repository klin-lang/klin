# Slice helpers — zero-alloc and `*_alloc`

Issue: [017](../issues/017-collection-methods.md). Fn pointers: [13-fn-ptr.md](13-fn-ptr.md).
Allocator: [14-allocator.md](14-allocator.md).

## Two modules

| Module | Role | Heap |
|---|---|---|
| [`stdlib/slice.kl`](../stdlib/slice.kl) | reads + `*_into` | no — freestanding-safe |
| [`stdlib/slice_alloc.kl`](../stdlib/slice_alloc.kl) | `map_alloc_*` / `filter_alloc_*` | yes — `import mem` |

Separate `slice_alloc`, because emit does not remove unused `pub`: if `*_alloc`
lived in `slice.kl`, every `import slice` would pull in `klin_mem_*` / `malloc`.

Generics here are `$fn`, not `[T]` in the compiler
([04-macros.md](04-macros.md)): `$slice_ops(i32)` becomes `each_i32`.
Operations split into two templates: general `slice_ops`
(arithmetic-free — works for any type) and numeric `slice_num_ops`
(`+`/`*`/`<`/`==` — instances only for numeric types).

## Layer 0+1 (`import slice`)

```klin
import slice

fn times2(x: i32): i32 { return x + x }
fn is_pos(x: i32): bool { return x > 0 }
fn add(a: i32, b: i32): i32 { return a + b }

fn main() {
    let xs: [4]i32 = [1, 0 - 2, 3, 0]
    let mut out: [4]i32 = [0, 0, 0, 0]
    let _ = slice.map_into_i32(xs[:], out[:], times2) or { 0 }
    let n = slice.filter_into_i32(xs[:], out[:], is_pos) or { 0 }
    let s = slice.reduce_i32(xs[:], 0, add)
}
```

General (`$fn slice_ops`, any type):

| Function | Notes |
|---|---|
| `each_*` | side effect |
| `index_of_*` | index or `-1` |
| `any_*` / `all_*` / `count_*` | |
| `reduce_*` | accumulator + `fn(T,T): T` |
| `map_into_*` | `dst.len == xs.len`; `!i32` (`0` / `error(1)`) |
| `filter_into_*` | `dst.len >= xs.len`; `!i32` = number written |
| `copy_into_*` | `dst.len >= xs.len`; `!i32` = `xs.len` |
| `reverse_into_*` | same; copies reversed |

Numeric (`$fn slice_num_ops`, numeric types only):

| Function | Notes |
|---|---|
| `sum_*` | sum; empty → `0` |
| `product_*` | product; empty → `1` |
| `min_*` / `max_*` | `!T`; empty → `error(1)` |
| `contains_*` | `bool` (`==` comparison) |

Instances: `slice_ops` for `i32`/`u8`/`i64`/`f64`; `slice_num_ops` for the same
numeric types.

Writing `dst[i]` on a slice is allowed (header is by value; buffer shared
with caller — like Go).

Example: [`examples/slice_ops.kl`](../examples/slice_ops.kl).  
Golden: `test/slice_ops.kl`.

## Layer 2 (`import mem` + `import slice_alloc`)

```klin
import mem
import slice_alloc

fn times2(x: i32): i32 { return x + x }

fn main() {
    let mut a = mem.heap()
    let xs: [3]i32 = [1, 2, 3]
    let mut out = slice_alloc.map_alloc_i32(&a, xs[:], times2) or {
        mem.empty_i32()
    }
    defer mem.free_i32(&a, out)
}
```

| Function | Behavior |
|---|---|
| `map_alloc_*` | `alloc(xs.len)` + map; `![]T` |
| `filter_alloc_*` | two passes: `count` → `alloc(n)` → copy; `![]T` |

Instances for `i32`/`u8`/`i64`/`f64` (require `mem.alloc_*` of that type).

- Allocator: `*mut mem.Allocator` (like `mem.alloc_i32`)
- Allocation errors (`n < 0` / OOM) from `mem` via `!` / `or`
- **Caller** frees: `defer mem.free_i32(&a, out)` — API does not `defer`
- Predicate in `filter_alloc` like in `count`: no side effects between passes

Example: [`examples/slice_alloc_demo.kl`](../examples/slice_alloc_demo.kl)
(do not name the file `slice_alloc.kl` next to `import slice_alloc` — path collision).  
Golden: `test/slice_alloc_ops.kl`.

## Non-goals

- Bare `xs.map(f)` / hidden `malloc`
- `using` / autofree of result
- Closures (D7); `[T]` in the compiler ([034](../issues/034-generic-types.md) — `$fn` is the generic)
- Methods on `[]T` as receiver
