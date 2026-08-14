# Write a Klin program

A short path from `hello` to methods, errors, and C — not a language
spec. Feature notes live in this folder; the map is [README.md](README.md).

Run everything below with a host C compiler on `PATH`:

```sh
klin run examples/hello.kl
# from a clone, before `brew install`:
dart run bin/klin.dart run examples/hello.kl
```

`--emit-c` writes the generated C and stops. That file is ordinary C.

## 1. Hello

```klin
fn main() {
    puts("hello from Klin")
}
```

`puts` and `printf` are the only C functions allowed without a
declaration. Everything else needs `@[cimport]` ([09-ffi-c.md](09-ffi-c.md)).

## 2. Values

```klin
fn main() {
    let n: i32 = 3          // immutable
    let mut acc = n         // `let mut` — or `acc := n`
    acc = acc + 1
    printf("%d\n", acc)
}
```

- Integers: `i8`…`i64`, `u8`…`u64`, alias `int` → `i32`
- Floats: `f32` / `f64`, alias `float` → `f64`
- `bool`, `str` (C string pointer — no `==` on content; use `import str`)
- Literals: `0xFF`, `0b1010`, `0o755`, `1_000`, `1.5e-3`, `'A'`
- No implicit numeric truthiness: `if` wants `bool`

`:=` is sugar for `let mut` ([14-short-decl.md](14-short-decl.md)).

## 3. Functions and structs

```klin
struct Vec2 {
    x: i32
    y: i32
}

fn (v: Vec2) len_sq(): i32 {
    return v.x * v.x + v.y * v.y
}

fn (mut v: Vec2) translate(dx: i32, dy: i32) {
    v.x = v.x + dx
    v.y = v.y + dy
}

fn main() {
    let mut p = Vec2{ x: 3, y: 4 }
    printf("len_sq=%d\n", p.len_sq())
    p.translate(1, 1)
    printf("p=(%d,%d)\n", p.x, p.y)
}
```

`fn (v: Vec2)` copies. `fn (mut v: Vec2)` takes a pointer. Mutation is
visible at the call site. In C, `mut` is gone — only `*` remains.

Parameters and fields may share a type: `fn add(a, b: i32)`,
`struct Point { x, y: f64 }`.

Runnable: [`examples/vec2.kl`](../examples/vec2.kl).

## 4. Errors are values

```klin
fn level(x: i32): !i32 {
    if x < 0 { return error(1) }
    return x
}

fn main() {
    let a = level(7) or { 0 }     // handle here
    let b = level(-1) or {
        printf("err=%d\n", err)
        99
    }
    printf("%d %d\n", a, b)
}
```

- `!T` is a tagged struct in C (flag + value)
- `expr!` propagates: `if (r.is_err) return r;`
- `or { … }` handles locally; `err` is in scope
- Ignoring a `!T` is a compile error
- No exceptions, no `null`

## 5. Pointers, arrays, slices

```klin
fn sum(xs: []i32): i32 {
    let mut i = 0
    let mut acc = 0
    while i < xs.len {
        acc = acc + xs[i]
        i = i + 1
    }
    return acc
}

fn main() {
    let xs: [3]i32 = [1, 2, 3]
    printf("%d\n", sum(xs[:]))    // array → slice
}
```

- `*T` / `*mut T` — address `&x`, write `*p = …`, fields `(*p).x`
- `[N]T` — fixed array (length in the type)
- `[]T` — slice `{ ptr, len }` (and `cap` where allocated)
- No hidden allocation. Heap is `import mem` and an explicit
  `Allocator` ([14-allocator.md](14-allocator.md))

## 6. Talk to C

```klin
@[cinclude("<math.h>")]
@[cimport, codename("sqrt")]
fn sqrt(x: f64): f64

@[link("-lm")]
```

The other direction: `@[cexport, codename("klin_add")]` plus
`--emit-h`. Details: [09-ffi-c.md](09-ffi-c.md).

## 7. What next

| Topic | Where |
|---|---|
| `match` / `pick` | [15-match.md](15-match.md), [18-pick.md](18-pick.md) |
| Modules / packages | [12-modules.md](12-modules.md), [11-klin-libraries.md](11-klin-libraries.md) |
| `$fn` macros | [04-macros.md](04-macros.md) |
| Interpolation | [07-interpolation.md](07-interpolation.md) |
| Host stdlib | [../stdlib/README.md](../stdlib/README.md) |
| MCU / `klin init` | [embedded.md](embedded.md) |
| Why these choices | [00-idea.md](00-idea.md), [01-decisions.md](01-decisions.md) |

Inspect generated C at any time:

```sh
klin --emit-c examples/vec2.kl
# → out/vec2.c
```
