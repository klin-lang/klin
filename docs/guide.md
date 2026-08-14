# Write a Klin program

A short path from `hello` to control flow, modules, errors, and C — not
a language spec. Feature notes live in this folder; the map is
[README.md](README.md).

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

## 4. Control flow

```klin
fn main() {
    for i in 1..<6 {
        if i % 2 == 0 {
            printf("even %d\n", i)
        } else if i == 1 {
            puts("one")
        } else {
            printf("%d\n", i)
        }
    }

    for j = 0; j < 3; j = j + 1 {
        if j == 1 { continue }
        printf("j=%d\n", j)
        if j == 2 { break }
    }
}
```

- `if` / `else if` / `else` — the condition is `bool` only (`if n` is an
  error; write `if n != 0`)
- `for i in 1..<6` — exclusive range; `i` is always `mut`
- `for i = 0; i < n; i = i + 1` — C-style, no parens; init introduces
  `mut i`
- `while cond { … }` — there is no V-style `for cond`
- `break` / `continue` work in both loops
- `match` / `pick` are later: [15-match.md](15-match.md),
  [18-pick.md](18-pick.md)

Runnable: [`test/fizzbuzz.kl`](../test/fizzbuzz.kl).

## 5. Errors are values

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
- Keyword `or` is **error-handling**, not logical OR (`||`)
- Ignoring a `!T` is a compile error
- No exceptions, no `null`

## 6. `defer`

```klin
import mem

fn main() {
    let mut a = mem.heap()
    let mut buf = a.alloc_bytes(8) or { mem.empty_u8() }
    defer a.free_bytes(buf)
    buf[0] = 1
}
```

`defer` registers a statement that runs when the **current block**
exits — `return`, `break`, `continue`, or falling off the end. Several
`defer`s in one scope run **last-in, first-out**.

The compiler inserts that statement at every exit from the block
(visible copies in the `.c`). There is no hidden destructor.

Runnable: [`examples/mem_heap.kl`](../examples/mem_heap.kl).

## 7. Pointers, arrays, slices

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

## 8. Modules and `import`

```klin
module app
import geom
import util calc          // local alias (issue 048)
import mem                // stdlib
```

Use imported names with a qualifier: `geom.Vec2{ x: 3, y: 4 }`,
`calc.add(2, 3)`, `mem.heap()`.

- `module name` — this file (or directory package) belongs to `name`
- `import name` — bring `name` in; symbols stay `name.Symbol`
- `import path alias` — same module, shorter qualifier
- `pub` — visible after import; without `pub` the symbol is private
  (`static` in the generated C)
- The whole program is still **one** `.c`

Search paths (`lib/`, `-I`, `KLIN_PATH`, remote `klin get`):
[11-klin-libraries.md](11-klin-libraries.md). Details:
[12-modules.md](12-modules.md).

Runnable: [`examples/modules/app.kl`](../examples/modules/app.kl).

## 9. Operator precedence

Tightest at the top. Assignment is a statement, not an operator here.

| | Operators | Notes |
|---|---|---|
| postfix | `()` `.` `[]` `!` | `!` after a value is error propagate (`expr!`) |
| unary | `-` `!` `~` `*` `&` | `*` / `&` vs multiply / bitwise AND: by position |
| mul | `*` `/` `%` | |
| add | `+` `-` | |
| shift | `<<` `>>` | integers only |
| bit-and | `&` | tighter than comparisons (Rust, **not** C) |
| bit-xor | `^` | |
| bit-or | `\|` | |
| cmp | `<` `>` `<=` `>=` | |
| eq | `==` `!=` | |
| and | `&&` | `bool` only, short-circuit |
| or | `\|\|` | `bool` only, short-circuit |
| error-or | `or { }` | loosest; D2 error handling, not `\|\|` |

So `flags & mask == bit` means `(flags & mask) == bit`. In C the same
tokens mean `flags & (mask == bit)`. Emission still parenthesizes so
the `.c` keeps Klin’s order ([01-decisions.md](01-decisions.md) D8 / D9).

`&&` / `||` do not accept integers. `or` without `{ }` is a parse
error.

Runnable: [`examples/bitwise.kl`](../examples/bitwise.kl),
[`examples/logical.kl`](../examples/logical.kl).

## 10. Talk to C

```klin
@[cinclude("<math.h>")]
@[cimport, codename("sqrt")]
fn sqrt(x: f64): f64

@[link("-lm")]
```

The other direction: `@[cexport, codename("klin_add")]` plus
`--emit-h`. There is no `c("…")` snippet — C stays in `.c` / headers
you declare. Details: [09-ffi-c.md](09-ffi-c.md).

A one-instruction GNU insert exists for ASM:

```klin
fn wait() {
    asm("wfi")
}
```

That becomes `asm volatile("wfi");` in the `.c`. Whole `.s` / `.S`
files use `@[link]` ([10-asm.md](10-asm.md),
[`examples/asm_add/`](../examples/asm_add/)).

## 11. What next

You can write host Klin now. Next, still without `issues/`:

1. A register — [device.md](device.md)
2. A small firmware project — [embedded.md](embedded.md)

| Topic | Where |
|---|---|
| What is in the language | [language.md](language.md) (`$fn` is the generic) |
| `match` / `pick` | [15-match.md](15-match.md), [18-pick.md](18-pick.md) |
| Enums / `table[Slot.B]` / `Type.fn` / destructuring | [syntax.md](syntax.md) |
| Packages / search paths | [11-klin-libraries.md](11-klin-libraries.md), [12-modules.md](12-modules.md) |
| Generics (`$fn`, not `[T]` in the compiler) | [04-macros.md](04-macros.md) |
| Interpolation | [07-interpolation.md](07-interpolation.md) |
| Host stdlib | [../stdlib/README.md](../stdlib/README.md) |
| C FFI / ASM units / `asm("…")` | [09-ffi-c.md](09-ffi-c.md), [10-asm.md](10-asm.md) |
| Why these choices | [00-idea.md](00-idea.md), [01-decisions.md](01-decisions.md) |

Inspect generated C at any time:

```sh
klin --emit-c examples/vec2.kl
# → out/vec2.c
```
