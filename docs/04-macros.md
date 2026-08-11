# Compile-time macros (`$fn`, D3)

Decision: [01-decisions.md](01-decisions.md) § D3. Issue: [026](../issues/026-preprocessor.md).
Example: [`point.kl`](../examples/point.kl) (plain Klin) and
[`point_macro.kl`](../examples/point_macro.kl) (same via `$fn`).

## Why

Generics are **not** in the language grammar. Instead a preprocessor before
parse/check/emit substitutes slots (`$name`, `$T`, …) and generates plain
Klin code — monomorphization visible in `--emit-pp`, zero runtime overhead.

## Before (you write a template)

```klin
$fn point(name: name, T: type) {
  struct $name {
    x: $T
    y: $T
  }
  fn (p: $name) len_sq(): $T {
    return p.x * p.x + p.y * p.y
  }
}

$point(Vec2i, i32)

fn main() {
  let v = Vec2i{ 3, 4 }
  printf("%d\n", v.len_sq())
}
```

A second call `$point(Vec2f, f64)` would produce a separate copy with `f64`.

## After expand (what checker / emit see)

```klin
struct Vec2i {
  x: i32
  y: i32
}
fn (p: Vec2i) len_sq(): i32 {
  return p.x * p.x + p.y * p.y
}

fn main() {
  let v = Vec2i{ 3, 4 }
  printf("%d\n", v.len_sq())
}
```

Preview:

```sh
dart run bin/klin.dart --emit-pp examples/point_macro.kl
# → out/point_macro.pp.kl
```

## Macro parameters (MVP)

| Kind | Argument | Substitution |
|---|---|---|
| `type` | `i32`, `f64`, … | as written |
| `name` / `str` | `Vec2i` or `"Vec2i"` | identifier (quotes from `str` are stripped) |
| `name` (numeric) | `512` | digit token as written |
| `block` (last only) | trailing `{ … }` after the call | body text (no outer braces) |

Definition: `$fn name(param: kind, …) { … }`.  
Call: `$name(args…)` or `$name(args…) { … }` when the last parameter is `block`.
Unknown `$slot` in body after expand = error (except `$…` inside strings and
`//` comments).

Nested calls are expanded: a `block` argument may contain another `$name(…)`,
so `$rtos_task(…) { $event_loop(ex) { … } }` works (issue 029).

### Macros from path imports (059 A1 lite)

`$fn` definitions in a package reached by `import "…"` (relative or
`github`/`gitlab` cache) are visible in the importing file. The import
qualifier (alias or last path segment) substitutes `$mod` in those macros.

```klin
import "../../mylib" lib
$lib_helper(x)   // if mylib defines $fn lib_helper …
```

Ident imports (`import slice`) do not re-export `$fn`; those packages expand
macros inside their own files (as today).

## Built-in: `$device` / `$peripherals_from_svd` (027, 053)

```klin
// locally (027) or remote with cache (053):
$device("github/tinygo-org/stm32-svd/svd/stm32f411.svd", "RCC,GPIOA,STK")
// alias: $peripherals_from_svd("…", "…")

fn main() {
  RCC.AHB1ENR.GPIOAEN.set(1)
  GPIOA.MODER.MODER5.write(.Output)
  GPIOA.ODR.ODR5.toggle()
}
```

Expand → `@[cinclude("…_regs.h")]` + `RCC_AHB1ENR_GPIOAEN_set(1)` etc.
(reuses emitter from 011; zero-cost `static inline`).

Examples:
- local: [`examples/stm32/blink_f411/`](../examples/stm32/blink_f411/)
- remote + `klin.mod`: [`examples/stm32/device_f411/`](../examples/stm32/device_f411/)
  (`klin get` in example dir → cache + `klin.lock`)

MVP allowlist: `github/tinygo-org/stm32-svd`.

### `$board("path.ioc")` — CubeMX pinout (issue 074)

Narrow expand: labeled GPIOs → `BoardPort` / `BoardPin` enums (not HAL, not
clocks, not generated `main`). Local project `board/*.ioc` wins over cache;
`klin get` of a remote `.ioc` fills `$KLIN_CACHE/asset/` only and **does not**
overwrite a local file.

```klin
$board("board/nucleo_f411re.ioc")
// BoardPin.LD2 == 5, BoardPort.LD2 == 0 (PA5)
```

Example: [`examples/stm32/device_f411/`](../examples/stm32/device_f411/).
Remote allowlist: `github/klin-lang/boards`,
[`github/klin-lang/nucleo_f411re`](https://github.com/klin-lang/nucleo_f411re)
([096](../issues/096-board-nucleo-f411re.md)).

## What this is not

- Not Nelua with full AST-quote / metaprogramming.
- Not hidden polymorphism in C — `.c` keeps plain `Vec2i` / `int32_t`.
