# 083 — `stdlib/math` — thin libm helpers

**Status:** ✅ done
**Depends on:** [012](012-stdlib-io.md) (stdlib module pattern), [021](021-c-libraries.md) (FFI / `@[link]`)

## Goal

Optional host module for common floating-point math — Klin style like
`io` / `str`, **not** a global JS `Math` object:

```klin
import math
let y = math.sin(x)
let a = math.abs(-2.5)
```

Thin `@[cimport]` over `<math.h>` + `@[link("-lm")]`. Cost is a call (libm)
unless the helper is plain Klin (`sqr` / `cube` / `div_*` / constants).

## API (`f64` unsuffixed; `f32` as `*_f32`)

| Klin | C / body |
|---|---|
| `sin` / `cos` / `tan` | `sin` / `cos` / `tan` |
| `sin_f32` / `cos_f32` / `tan_f32` | `sinf` / `cosf` / `tanf` |
| `sqrt` / `sqrt_f32` | `sqrt` / `sqrtf` |
| `cbrt` / `cbrt_f32` | `cbrt` / `cbrtf` (negative bases OK) |
| `abs` / `abs_f32` | `fabs` / `fabsf` |
| `floor` / `ceil` / `floor_f32` / `ceil_f32` | `floor` / `ceil` / `floorf` / `ceilf` |
| `pow` / `pow_f32` | `pow` / `powf` |
| `root` / `root_f32` | Klin `pow(x, 1/n)` / `powf` — IEEE `pow` on negative bases, not `cbrt` |
| `log` / `log10` / `log2` | `log` (ln) / `log10` / `log2` |
| `log_f32` / `log10_f32` / `log2_f32` | `logf` / `log10f` / `log2f` |
| `min` / `max` | `fmin` / `fmax` |
| `min_ieee_f32` / `max_ieee_f32` | `fminf` / `fmaxf` (NaN rules) |
| `clamp` | Klin over `min`/`max` (f64) |
| `min_*` / `max_*` / `clamp_*` | typed (`i32`/`i64`/`u8`/`u16`/`u32`/`u64`/`f32`/`f64`) via `$fn` — comparison, no overload |
| `sqr` / `cube` / `sqr_*` / `cube_*` | `x*x` / `x*x*x` (no libm; unsuffixed = f64) |
| `div_*` | `Div_$T { quot, rem }` from `a / b` and `a % b` (integers only) |
| `pi()` / `di()` / `e()` | Klin literals (`di` = 2π; no module-level `const`) |
| `pi_f32()` / `di_f32()` / `e_f32()` | f32 literals |

```klin
let { quot, rem } = math.div_i32(17, 5)   // 3, 2
```

No tuples — named struct + destructuring ([056](056-destructuring.md)).

## Delivered

- [`stdlib/math.kl`](../stdlib/math.kl)
- Golden [`test/math_basic.kl`](../test/math_basic.kl)
- Example [`examples/math_basic.kl`](../examples/math_basic.kl)

## Out of scope

- Language-level overloading of `min`/`max`/`clamp` / `sin(f32)`
- Operator `**`, type `f16`, tuples / multi-return
- Integer `abs`, `isqrt` / integer nth root (float cast is wrong for `i64`)
- `random`, full `<math.h>`, complex numbers, float `modf` / `remainder`
- Bare-metal without libm (simply do not `import math` — module still carries `-lm` for trig)
