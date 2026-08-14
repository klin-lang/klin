# Generics via `$fn` (not `[T]` in the compiler)

Klin **has** generics. They are `$fn`, not `fn id[T]` / `Vec[T]`.
That is a conscious choice ([D3](01-decisions.md)): a preprocessor
monomorphizes **before** parse. The checker and the C emitter never
see a type parameter. Language surface (do not propose `[T]`):
[language.md](language.md).

`$point(Vec2i, i32)` becomes a plain `fn`. In a program you call
`each_i32`, not `each[i32]`. Issue [034](../issues/034-generic-types.md)
is optional grammar sugar later — not a hole, and not “missing
generics.”

Decision: [01-decisions.md](01-decisions.md) § D3. Implementation:
[026](../issues/026-preprocessor.md). Example:
[`point.kl`](../examples/point.kl) (plain Klin) and
[`point_macro.kl`](../examples/point_macro.kl) (same via `$fn`).
Stdlib: [`slice`](../stdlib/slice.kl) (`$slice_ops(i32)` → `each_i32`).

## Pipeline

1. You write a `$fn` template and call it (`$point(Vec2i, i32)`).
2. Expand (`--emit-pp`) substitutes `$name` / `$T` and emits **plain
   Klin** — ordinary `struct` / `fn`.
3. Parse → check → emit C see only that plain Klin. Nothing generic
   remains at runtime.

## Why `$fn` instead of compiler generics

A C backend must monomorphize anyway. `each[T]` and `$fn each_$T`
produce the **same** `.c`. Putting `T` in the checker is a large
frontend for naming (`map_into[T]` vs `map_into_i32`), not a different
execution model. So Klin keeps `[T]` out of the compiler on purpose.

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

## Built-in: `$device` / `$board`

User page (SVD, fluent MMIO, fetch, pinout): [device.md](device.md).

`$device` / `$peripherals_from_svd` and `$board` are preprocessor
builtins in the same `$` family as `$fn`. They expand **before** parse
and are not valid Klin until `--emit-pp`.

## What this is not

- Not `fn foo[T]` / `Vec[T]` in the parser or checker ([034](../issues/034-generic-types.md)).
- Not Nelua with full AST-quote / metaprogramming.
- Not hidden polymorphism in C — `.c` keeps plain `Vec2i` / `int32_t`.
