# The rest of the syntax

Everyday forms that are not in the [guide](guide.md). Still not a
language spec — each block vanishes in C emission.

## Enums

A named integer type, not an `i32` alias. Default base is `i32`.
Values start at 0 and count up unless you write `= N`.

```klin
enum Color { Red, Green, Blue }
enum Status: u8 { Ok, Warn = 5, Err }

fn (c: Color) name(): str {
    match c {
        Color.Red { return "red" }
        Color.Green { return "green" }
        Color.Blue { return "blue" }
    }
}
```

- `==` / `!=` only with the **same** enum; no `<` / `>`
- `match` patterns are `Enum.Variant`. The checker requires every
  variant (or a final `else`). A `when` guard does not count — it can
  fail. `else` is the hatch for a leftover after `cast`.
- Number conversion is explicit: `cast(i32, s)`, `cast(Status, 5)`
- An implicit next value must fit the base type. `enum E: u8 { A = 255, B }`
  is an error (`B` would be 256). `enum E: u8 { A = 255 }` is fine — the
  unused next value is not a variant. An explicit `= 300` is still the
  integer-literal range error
- Receiver methods work like on structs
- Emission is a `typedef` plus integer constants (portable; not C23
  `enum E : T`)

An enum can index a **fixed** array when every variant fits `[0, N)`.
Same load as `codes[cast(i32, Slot.B)]` — not a map.

```klin
enum Slot { A, B, C }
let codes: [3]i32 = [10, 20, 30]
printf("%d\n", codes[Slot.B])   // 20
```

`enum Slot { A, B = 5 }` on `[3]i32` is a checker error. Slices (`[]T`)
still want an integer. Integer indexes were already any integer prim
(`i8`…`u64`, `usize` / `isize`, `int`) — not only `i32`.

Not in the language: payload / algebraic variants, string-enums,
auto `to_string`.

Runnable: [`examples/enums.kl`](../examples/enums.kl),
[`examples/sorted_lookup.kl`](../examples/sorted_lookup.kl).
Issues: [072](../issues/072-enums.md), [126](../issues/126-enum-index.md),
[129](../issues/129-enum-match-exhaustive.md).

## Numeric `cast`

Concrete numeric types do **not** convert implicitly. Use the same
`cast(T, expr)` form as for enums (issue [154](../issues/154-numeric-cast.md)):

```klin
let a: i32 = 40
let b: i64 = cast(i64, a)
let c: f64 = cast(f64, a)
let d: u8 = cast(u8, 300)       // truncates like C → 44
let e: i32 = cast(i32, cast(f64, 3.9))  // toward zero → 3
```

- Allowed: integer ↔ integer, float ↔ float, integer ↔ float
  (`i8`…`i64`, `u8`…`u64`, `usize`/`isize`, `f32`/`f64`, aliases
  `int`/`float`). Same-type cast is a no-op.
- Semantics = a plain C cast (truncation / wrap; no saturating /
  checked casts in the language).
- Untyped int literal may target integer or float; untyped float
  literal may target float only (`cast(i32, 1.5)` is an error — cast
  to a float first).
- Not allowed: `bool`, struct/array/slice/`str`, float ↔ enum.
- Pointer casts stay separate. Integer or pointer → pointer is
  `(T *)(uintptr_t)…`, except a signed integer, which uses `intptr_t`.
  Pointer → integer is `(target)(uintptr_t)ptr` for an unsigned target
  and `(target)(intptr_t)ptr` for a signed one. Not float, not `bool`,
  not a function pointer ([D17](01-decisions.md)).

Runnable: [`examples/numeric_cast.kl`](../examples/numeric_cast.kl).

## Associated functions (`Type.fn`)

A function on a type with **no** instance receiver. Declaration
mirrors the call. Emits a plain C function `Type_name(...)`.

```klin
fn Color.from_u8(n: u8): !Color {
    if n == 1 { return Color.Green }
    return error(1)
}

fn Point.new(x, y: i32): Point {
    return Point{ x: x, y: y }
}

let c = Color.from_u8(1) or { Color.Red }
let p = Point.new(3, 4)
```

- Works on **enums and structs**
- `Color.Red` (no `()`) is still the constant; `Color.from_u8(...)`
  is the function
- After `import`, use `pub` and `mod.Type.func(...)`
- Opposite of `fn (c: Color) name()` — one has a receiver, one does not

No generated `values()` / `valueOf`. No overloading.

Runnable: [`examples/associated_fn.kl`](../examples/associated_fn.kl).
Issue: [079](../issues/079-associated-functions.md).

## Destructuring

Unpack a value into names. Not RAII — Klin has no destructors (D6).
No tuple type.

```klin
let p = Vec2{ x: 3, y: 4 }
let { x, y } = p              // fields by name; subset and order OK
let { x: px } = p             // rename
let mut { x } = p             // mutable locals

let mut x = 0
let mut y = 0
{ x, y } = p                  // assign into existing places

let xs: [4]i32 = [10, 20, 30, 40]
let [a, b, c, d] = xs         // `[N]T` only; count must equal N
let [_, mid, _, last] = xs    // `_` skips a slot
```

```klin
let mut a = 1
let mut b = 2
a, b = b, a                   // multi-assign; temps in the .c
```

Each form lowers to `.field` / `xs[i]` / ordinary temps. The source
of a `{}` / `[]` unpack is evaluated once.

Not supported: slice `[]T` (length is runtime), bare `[a, b] = xs`
(a leading `[` is an index), tuples, patterns in `if` / `match`.

Runnable: [`examples/destructure.kl`](../examples/destructure.kl),
[`examples/multi_assign.kl`](../examples/multi_assign.kl).
Issue: [056](../issues/056-destructuring.md).

## Slices of any value

`[]T` is `{ ptr, len }`. `T` may be a primitive, a struct, an enum,
`str`, a pointer, a slice, a function pointer, or an array that is
not an array of structs. `[]!T` and `[]void` are errors.

```klin
struct Token {
    kind: i32
    n: i32
}

fn main() {
    let mut xs: [2]Token = [Token{ kind: 1, n: 2 }, Token{ kind: 3, n: 4 }]
    let mut s = xs[:]
    s[0].n = 9
    printf("%d\n", s[0].n)
}
```

`xs[:]` needs the array as an l-value. Indexing is a C index (no
runtime check). A write and `&s[i]` follow the slice place: `let mut`
can write, an immutable binding cannot. `struct Node { kids: []Node }`
is a slice of the same struct.

Runnable: [`examples/slice_struct.kl`](../examples/slice_struct.kl).

## Subslice

`xs[a:b]`, `xs[a:]`, and `xs[:b]` on an array or a slice build a
`[]T` over that range. `a` and `b` are integers (or an enum, the same
way an array index is). No runtime check: a bound past the length,
`a > b`, or a negative bound is undefined behavior. A call in
`take(xs)[a:]` runs once each time that subslice is evaluated,
including the condition of a loop.

```klin
fn main() {
    let mut xs: [5]i32 = [10, 20, 30, 40, 50]
    let mut mid = xs[1:4]
    mid[0] = 7
    printf("%d %d\n", mid.len, xs[1])
}
```

`xs[a:b][i] = …` follows the source place (`let mut xs`, a `let mut`
slice). A new binding follows that binding: `let mid = xs[a:b]` cannot
write, `let mut mid` can. A slice parameter, `b"…"`, and a `const`
cannot. An array subslice needs an l-value. Runnable:
[`examples/slice_range.kl`](../examples/slice_range.kl).

## `main` arguments

`fn main()` or `fn main(args: []str)`. The parameter is the process
arguments as an immutable slice: `.len` is `argc` (it counts `argv[0]`),
and `args[i]` is `argv[i]`. C is `int main(int klin_argc, char **klin_argv)`
plus one header. No copy and no check that `argc` is negative.
`[][]u8` is not this parameter — that would walk each string.
See [D18](01-decisions.md). Runnable:
[`examples/main_args.kl`](../examples/main_args.kl).

## Function field call

`h.cb(1)` calls a field of type `fn(…)`. `(*p).cb(1)` does too.
`p.cb(1)` on a pointer does not (no auto-deref). If `Holder` has both
a method `cb` and a function field `cb`, the call is an error. A
non-function field does not hide a method. See
[D16](01-decisions.md). Runnable:
[`examples/fn_field.kl`](../examples/fn_field.kl).

## Byte strings

`"..."` is `str` (`const char*`). `b"..."` is `[]u8`: the bytes of the
text and a length. No interpolation. Escapes match `"..."`:
`\n`, `\t`, `\\`, `\"`, `\$`, `\0`.

`\0` is a single NUL byte in both forms. `.len` on a byte string counts
it (`b"ab\0".len` is 3). `str` has no length, so a C string operation on
`"..."` stops at the first NUL; a counted buffer uses `b"..."`. `\0` is
not an octal number — `b"\00"` is NUL then the character `0`.

```klin
fn take(s: []u8): i32 { return s.len }

fn main() {
    let kw = b"fn"
    printf("%d %d\n", kw.len, kw[0])   // 2, 102
    printf("%d\n", take(b"ab\n"))      // 3
}
```

The slice points at static bytes (no allocation). Those bytes are
read-only: `b"fn"[0] = 1` is an error, and so is a write through an
immutable slice (`let s = b"fn"` then `s[0] = 1`, or a `[]u8`
parameter). `let mut s = b"fn"` then `s[0] = 1` still compiles and
can crash — a mutable slice has no read-only flavor. Copy into a
`[N]u8` to modify.

## Constants

`const` is a module-level compile-time value. It is not storage and
not a local (`let` at module scope is the object; a local stays `let`
inside a function).

```klin
pub const PAGE: i64 = 4096
const FLAG: bool = true
const NEG: i32 = -100
const KW: []u8 = b"fn"

fn main() {
    let buf: [PAGE]u8
    printf("%d %d %d\n", cast(i32, PAGE), KW.len, buf.len)   // 4096, 2, 4096
}
```

- Type is required: an integer, `bool`, or `[]u8`
- `bool` is `true` / `false`. `[]u8` is `b"..."`. An integer initializer
  is a constant expression: literals, unary `-` / `~`, `+ - * / % << >>
  & | ^`, and other integer constants (`N`, `mod.NAME`, including one
  declared later). A cycle is an error. A named constant of a different
  integer type is a type mismatch
- `pub` is visible as `mod.NAME` after `import`. Private is
  `static const` in the generated C
- `NAME = …` is an error. `KW[0] = 1` is an error. A local of the same
  name shadows the constant in a value, not in a type
- That expression is a valid `[N]T` length (`[N]u8`, `[os.PAGE]u8`,
  `[N * 2]u8`, `[1 + 2]u8`) in a local, a struct field, or a parameter.
  The C bound is the folded integer (a decimal). A `bool`, a `[]u8`, a
  negative value, or a value above `2^63-1` is an error
- The value must fit the declared integer type (`const X: u8 = 300`,
  `const X: u8 = 200 + 100`, and `const X: u8 = -1` are errors). The
  diagnostic is the same as a literal ([D12](01-decisions.md)). `cast`
  still truncates. Division or remainder by zero is an error. A shift
  by a negative count, or by a count at least as wide as the type, is
  an error
- `-literal` and `~literal` take the constant's type (`const M: u32 = ~0`,
  `const MIN: i8 = -128`). A folded expression is emitted as a decimal;
  a lone literal and `~` / `-` on a literal keep their spelling when
  that spelling is valid C. The same expression folds outside `const`
  when a type is expected (`let x: u8 = 1 + 2`, `return 1 + 2`,
  `[1 + 2]` as a `[1]u8` element). `let x: u8 = 200 + 100` is out of
  range. `~x` on a variable is still a runtime expression

```klin
module app
import os

fn main() {
    printf("%d\n", cast(i32, os.AT_FDCWD))
}
```

Runnable: [`examples/module_const.kl`](../examples/module_const.kl).

## Module-level `let`

`let` / `let mut` at module scope is an object. `const` has no address;
`let` does. `:=` is not allowed here.

```klin
const PAGE: i64 = 4096

let mut n: i32 = 1
let limit: i32 = PAGE
let mut buf: [8]u8
let mut p: *mut i32 = &n

fn bump() {
    n = n + 1
    *p += 1
}
```

- `let` is not assignable. `&` of it is `*T`. `let mut` is assignable,
  including compound assignment and a `for name = …` header. `&` of it
  is `*mut T`. A `mut` method accepts a `let mut` global
- The type is required. Omitted initializer means zero-init (C static
  storage). A present initializer must be a constant expression:
  literals, `const`, integer constant expressions, array and struct
  literals of those, `b"..."`, an enum variant, `&` of a global or
  function, `xs[:]` / `xs[a:b]` of a global array (constant bounds), or
  a function name. Another global's value is not a constant
- Types: prims, `str`, enums, structs, pointers, slices, function
  pointers, `[N]T`. Not `!T`
- `pub` is `mod.name` after `import`. Another module may write it only
  when it is `pub let mut`. Private is `static` and invisible across
  modules
- A global is not an `[N]T` length. A local of the same name shadows it
- No locks and no atomics. Async and threads race the way C does
- `let mut s: []u8 = b"..."` can write the read-only bytes and may crash
  (D10). Copy into a `[N]u8` to modify

Runnable: [`examples/global_let.kl`](../examples/global_let.kl).

## Already documented elsewhere

| Topic | Where |
|---|---|
| Tutorial (`if` / `defer` / `import` / …) | [guide.md](guide.md) |
| `match` / `pick` | [15-match.md](15-match.md), [18-pick.md](18-pick.md) |
| `:=` | [14-short-decl.md](14-short-decl.md) |
| Bitwise / `&&` `\|\|` | [01-decisions.md](01-decisions.md) D8 / D9 |
| Returning `[N]T` | [01-decisions.md](01-decisions.md) D13 |
| Empty array literal `[]` | [01-decisions.md](01-decisions.md) D12 |
