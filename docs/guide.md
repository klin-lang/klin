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
An untyped integer argument folds as `i32` (`printf("%d\n", 1 + 2)` is `3`).

`fn main()` takes no arguments. `fn main(args: []str)` is the process
arguments: `args.len` is `argc` (including the program name) and
`args[0]` is `argv[0]`. The slice is immutable. Other signatures are
an error ([D18](01-decisions.md)).

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
- `bool`, `str` (C string pointer — no `==` on content; use `import str`).
  `s.len` is `strlen` (`i32`, every time), `s[i]` is a read-only `u8`,
  and `cstr_u8(s)` is a read-only `[]u8` (D22). A `str` with no
  initializer is `""`, so `s.len` is 0 (D27). `b"..."` stays the
  counted buffer
- Literals: `0xFF`, `0b1010`, `0o755`, `1_000`, `1.5e-3`, `'A'`, `b"fn"` (`[]u8`, [syntax.md](syntax.md))
- No implicit numeric truthiness: `if` wants `bool`
- No implicit widen/narrow between concrete numeric types — use
  `cast(i64, n)` / `cast(f64, n)` ([syntax.md](syntax.md),
  [154](../issues/154-numeric-cast.md))
- An integer literal must fit the type it is coerced to. `let x: u8 = 300`,
  `const X: u8 = 0x12C`, and `const X: u8 = -1` are errors. The message
  names the type and its inclusive range. `cast(u8, 300)` still truncates
- `-1` and `~0` on an integer literal take the expected type:
  `let x: i64 = -1`, `take(-1)` for an `i64` parameter, `const M: u32 = ~0`.
  The range check applies to the result (`-128` fits `i8`). The same
  operators fold in any expected integer type, not only in a `const`
  or an `[N]T` length: `let x: u8 = 1 + 2` is `3`, and
  `let x: u8 = 200 + 100` is out of range for `u8`. A variable stays
  runtime (`y + 1`). On `u8` / `i8` / `u16` / `i16` that runtime result
  wraps to the type (two `u8` variables `200 + 100` is 44, and `> 255`
  is false). A shift whose count is negative or at least the width is
  `0`, or `-1` for arithmetic `>>` of a negative value (D26)

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
visible at the call site. The receiver may be any mutable place: a
`let mut`, a field or index of one, or a place reached through `*mut`
(`(*p).translate(...)`). `&` of that place has type `*mut`. A place
reached only through `*T` stays immutable. In C, `mut` is gone — only
`*` remains.

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

    for j := 0; j < 3; j += 1 {
        if j == 1 { continue }
        printf("j=%d\n", j)
        if j == 2 { break }
    }
}
```

- `if` / `else if` / `else` — the condition is `bool` only (`if n` is an
  error; write `if n != 0`)
- `for i in 1..<6` — exclusive range; `i` is always `mut`
- `for i := 0; i < n; i += 1` — C-style, no parens; `:=` declares
  `mut i` (`=` in init assigns to an existing mut — [14-short-decl.md](14-short-decl.md));
  post allows `=`, `+=`, or `-=`
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

    // Local match can also yield !T (issue 132) — no helper required:
    let s = match 1 {
        1 { "ok" }
        else { error(1) }
    } or { "??" }
    printf("%s\n", s)
}
```

- `!T` is a tagged struct in C (flag + value)
- `expr!` propagates: `if (r.is_err) return r;`. As a statement
  (`step(ok)!`) it discards the success value. The function must
  return `!T` either way. `main` is C `int`, so `!` is not allowed there
- `or { … }` handles locally; `err` is in scope. The block may end
  with a value, or leave with `return` / `break` / `continue` instead
  of a value (`let n = level(x) or { return err }`, D21)
- Keyword `or` is **error-handling**, not logical OR (`||`)
- `error(n)` builds a `!T` value (function return **or** `match` arm)
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

- `*T` / `*mut T` — address `&x`, write `*p = …`, fields `(*p).x`.
  A place reached through `*mut` is mutable: `&(*p).x` is `*mut`, and
  a mutating method may be called on it. Through `*T` it stays immutable.
  `&s[i]` on a slice is `*mut` when that slice place is mutable
  (`let mut s`, or `&xs[:][i]` when `xs` is `let mut`) and `*T` when
  it is not (an immutable binding, a slice parameter, an immutable array).
  Writing `s[i]` uses that same place: an immutable slice cannot be
  assigned (`s[i] = …`, `s[i] += …`). `let mut s` can, unless the
  header currently points at read-only bytes (`let mut s = b"fn"`
  can be reseated; `s[0] = 1` cannot until it views a mutable buffer).
- `[N]T` — fixed array. `N` is an integer constant expression: a
  literal, an integer module `const`, or arithmetic on those
  (`[N * 2]T`, `[1 + 2]T`). The C bound is the folded value.
  A constant integer index outside `0 .. N` is a compile-time error
  (`a[5]` on `[3]i32`). A runtime index is not checked.
  A literal `[1, 2]` takes the element type from that array
  (`let a: [2]u8 = [1, 2]`); each element must fit. Without a type,
  it is `[2]i32`. An empty literal `[]` is `[0]T` from the declaration
  (`let a: [0]u8 = []`, an argument, a field). Without an array type
  it is an error. A zero-length array is a C extension. A function
  may return `[N]T`. C cannot return an array, so the return is a
  struct with one field `v` (no allocation).
  `return [1, 2]` in `fn pair(): [2]u8` takes `u8` from the declaration.
  A local from a literal stays a C array; a local from the call is the
  struct (`a[0]` in Klin). A zero-length array cannot be returned, and
  `pick` / `match` cannot produce one
  ([01-decisions.md](01-decisions.md) D13)
- `[]T` — slice `{ ptr, len }` (and `cap` where allocated).
  `T` is a primitive, a struct, an enum, `str`, a pointer, a slice,
  a function, or an array that is not an array of structs.
  `xs[:]` on `[N]Token` is `[]Token`; `s[i].kind` reads a field.
  A slice of an array of structs (`[][N]Token`) is an error.
  Writes and `&s[i]` follow the slice place, same as `[]i32`.
  `xs[a:b]`, `xs[a:]`, and `xs[:b]` are a subslice of an array or a
  slice: a new `{ptr, len}` over the same elements, no bounds check.
  A write through that view follows the source place.
  `(*p)[:]`, `(*p)[a:b]`, `(*p)[a:]`, and `(*p)[:b]` do the same
  through `*mut [N]T` or `*[N]T`, and `(*p)[i]` indexes that array
  ([01-decisions.md](01-decisions.md) D19)
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
- `const NAME: Type = …` — module-level compile-time integer, `bool`, or
  `b"..."`. An integer initializer may name other constants and use
  `+ - * / % << >> & | ^` and unary `-` / `~`. That value is a valid
  `[N]T` length ([syntax.md](syntax.md))
- `let` / `let mut NAME: Type = …` — module-level storage. `let` is not
  assignable; `let mut` is. `pub let mut` may be written as `mod.name`
  from an import. The initializer is a constant expression, or omitted
  (zero). Not an `[N]T` length. No implicit synchronization
  ([syntax.md](syntax.md))
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
A `u8` / `i8` / `u16` / `i16` result is cast back to that width, and a
shift is a defined helper (D26).

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
