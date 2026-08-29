# Klin stdlib

Optional modules resolved after project / user library paths.

Search order for `import io` (first hit wins; in each slot, `io.kl` **or**
directory `io/` — both at once is an error):

1. `./io.kl` or `./io/` next to the importing file
2. `./lib/io.kl` or `./lib/io/`
3. each `-I <dir>/…` (CLI)
4. each `$KLIN_PATH` entry (`:` on Unix, `;` on Windows)
5. `$KLIN_STDLIB/…` if set
6. `<repo>/stdlib/…` (package root with `pubspec.yaml`)

User libraries / directory packages: [docs/11-klin-libraries.md](../docs/11-klin-libraries.md).

| Module | Role |
|---|---|
| [`io`](io.kl) | Host `print` / `println` (thin libc wrappers) |
| [`fmt`](fmt.kl) | `write(buf[:], …)` — interpolate / copy into caller `[]u8` ([156](../issues/156-fmt-write.md)) |
| [`str`](str.kl) | Host `eq` / `len` (thin `strcmp` / `strlen`; no `==` on `str`) |
| [`math`](math.kl) | Host `sin` / `sqrt` / `sin_f32` / `sqr` / `cbrt` / `div_i32` / … (libm + Klin helpers; `@[link("-lm")]`) |
| [`testing`](testing.kl) | `assert` / `assert_eq_i32` for `klin test` |
| [`time`](time.kl) | Wall / monotonic clocks, `Duration`, format, UTC calendar `add_*` |
| [`mem`](mem.kl) | Explicit host heap `Allocator` (`malloc`/`free`) |
| [`slice`](slice.kl) | Zero-alloc `each_i32` / `map_into_u8` / … (`$fn` generic → plain `fn`; [docs/04-macros.md](../docs/04-macros.md)) |
| [`slice_alloc`](slice_alloc.kl) | `map_alloc_*` / `filter_alloc_*` with explicit `Allocator` (pulls `mem`) |

## `io`

```klin
import io

io.print("no newline")
io.println("with newline")
```

Do **not** import on bare metal (pulls `stdio`).

## `fmt`

Write an interpolated string (or plain `str`) into a caller buffer — no hidden
heap ([issue 156](../issues/156-fmt-write.md), [docs/07-interpolation.md](../docs/07-interpolation.md)):

```klin
import fmt

fn main() {
    let mut buf: [64]u8
    let x = 7
    let n = fmt.write(buf[:], "x: $x")
    printf("%s\n", &buf[0])
}
```

Returns bytes written excluding NUL, or `-1` on error/truncation. Needs
`snprintf` (newlib-nano OK). Same `$` / `${…}` formats as print sinks.

## `str`

Content compare and length via libc ([issue 080](../issues/080-stdlib-str.md)).
Cost is a function call — `==` on `str` is intentionally unsupported:

```klin
import str

if str.eq(s, "red") { … }
let n = str.len(s)
```

Do **not** import on bare metal (pulls `string.h`).

## `math`

Floating-point helpers via libm ([issue 083](../issues/083-stdlib-math.md)).
Klin module style (`math.sin`), not a global JS `Math`:

```klin
import math

let y = math.sin(x)
let a = math.abs(-2.5)
let n = math.log(x)     // natural (ln)
let p = math.pi()
let t = math.di()       // 2π
let c = math.clamp_i32(x, 0, 100_000)
let f = math.clamp_f32(t, 0.0, 1.0)
let s = math.sqr(3.0)   // 9; also sqr_i32 / cube / cbrt / root
let { quot, rem } = math.div_i32(17, 5)
```

Typed `min_*` / `max_*` / `clamp_*` / `sqr_*` / `cube_*` for
`i32`/`i64`/`u8`/`u16`/`u32`/`u64`/`f32`/`f64` (no overloading).
`min`/`max`/`clamp` / `sin` / `sqrt` remain f64; `*_f32` is the float
libm twin (`sinf`, `sqrtf`, …). `min_ieee_f32` is `fminf` (NaN rules),
not comparison `min_f32`. `root(x, n)` is `pow(x, 1/n)`.

Integer `div_*` returns `Div_* { quot, rem }` — destructure, no tuples.

Links with `-lm`. Do **not** import on bare metal without libm.

## `testing`

Used by `klin test` on `*_test.kl` files. The harness injects `main` that
calls each `test_*` function:

```klin
import testing

fn test_add() {
    testing.assert_eq_i32(1 + 1, 2)
}
```

```sh
dart run bin/klin.dart test examples/
```

Bare-metal programs simply do not import these modules.

## `time`

Host clocks and formatting ([docs/08-time.md](../docs/08-time.md)):

```klin
import time

fn main() {
    let t = time.unix(1704067200)
    let mut buf: [32]u8
    time.format(buf[:], "%Y-%m-%d", t)
    printf("%s\n", &buf[0])
}
```

`now()` = wall, `mono()` = monotonic. RTC / CPU cycles are separate APIs.
Calendar: `add_days` / `add_months` / `add_years` / `add_date` (UTC, `!Instant`).
Do **not** import on freestanding targets without libc `time`.

## `mem`

Explicit heap allocator ([docs/14-allocator.md](../docs/14-allocator.md), D1):

```klin
import mem

fn main() {
    let mut a = mem.heap()
    let mut buf = a.alloc_bytes(16) or { mem.empty_u8() }
    defer a.free_bytes(buf)
}
```

`alloc_bytes` / `alloc_i32` (and `free_*`) call libc only when this module is
imported. Use `empty_u8` / `empty_i32` in `or` fallbacks (safe with `free_*`).
Do **not** import on freestanding targets without a heap.

## `slice`

Zero-alloc helpers via fn-pointers ([issue 017](../issues/017-collection-methods.md),
[docs/16-slice.md](../docs/16-slice.md), [docs/13-fn-ptr.md](../docs/13-fn-ptr.md)).
Names are monomorphized (`_i32`, `_u8`):

```klin
import slice

fn times2(x: i32): i32 { return x + x }

fn main() {
    let xs: [3]i32 = [1, 2, 3]
    let mut ys: [3]i32 = [0, 0, 0]
    let _ = slice.map_into_i32(xs[:], ys[:], times2) or { 0 }
}
```

Does **not** import `mem` — freestanding-safe. For heap results use `slice_alloc`.

## `slice_alloc`

Allocating helpers ([issue 017](../issues/017-collection-methods.md) layer 2,
[docs/16-slice.md](../docs/16-slice.md)). Separate from `slice` so zero-alloc
code stays free of `malloc`. Caller frees:

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

Do **not** import on freestanding targets without a heap.
