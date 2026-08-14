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
        else { return "blue" }
    }
}
```

- `==` / `!=` only with the **same** enum; no `<` / `>`
- `match` patterns are `Enum.Variant`; `match` is not exhaustive
- Number conversion is explicit: `cast(i32, s)`, `cast(Status, 5)`
- Array index: `codes[Slot.B]` when every variant fits `[0, N)` —
  same load as `codes[cast(i32, Slot.B)]`. Not a map. Slices still
  want an integer (`i8`…`u64`, `usize` / `isize`, or `int`)
- Receiver methods work like on structs
- Emission is a `typedef` plus integer constants (portable; not C23
  `enum E : T`)

Not in the language: payload / algebraic variants, string-enums,
auto `to_string`.

Runnable: [`examples/enums.kl`](../examples/enums.kl).
Issue: [072](../issues/072-enums.md).

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

## Already documented elsewhere

| Topic | Where |
|---|---|
| Tutorial (`if` / `defer` / `import` / …) | [guide.md](guide.md) |
| `match` / `pick` | [15-match.md](15-match.md), [18-pick.md](18-pick.md) |
| `:=` | [14-short-decl.md](14-short-decl.md) |
| Bitwise / `&&` `\|\|` | [01-decisions.md](01-decisions.md) D8 / D9 |
