# Design decisions

This is the decision log (D1–D22), not an introduction. Start with
[00-idea.md](00-idea.md). To write Klin: [guide.md](guide.md).

The first three must be made **before the first line of the parser** — they permeate
the symbol table, checker, and codegen. Changing them later means rewriting.

---

## D1. Memory lifetime model — DECIDED

**Choice: manual + `defer` + allocator as an explicit argument (Zig/Odin model).**

Rejected:
- **GC** — rules out bare-metal, breaks the overarching principle.
- **Borrow checker** — research problem. The Rust team spent years
  (NLL, Polonius) and is still adding. Solo = a project that never reaches 1.0.
- **Autofree** — see `00-idea.md`.

```
pub fn parse(a: *Allocator, src: []u8): !Doc {
    let buf = a.alloc(u8, src.len)   // sketch — MVP: alloc_bytes / alloc_i32
    defer a.free(buf)
    ...
}
```

MVP host: [`stdlib/mem`](../stdlib/mem.kl) (`heap`, `alloc_bytes`, `alloc_i32`) —
[docs/14-allocator.md](14-allocator.md), issue [057](../issues/057-allocator.md).

**Do not promise** `a.alloc(u8, n)` until there is a type argument in the call
(generics [034](../issues/034-generic-types.md) / D3 sugar). Today: `alloc_bytes`
+ explicit `alloc_i32` / `alloc_u8`. `slice_alloc.map_alloc_*` —
[017](../issues/017-collection-methods.md) / [docs/16-slice.md](16-slice.md).
Arena, vtable — later (see docs/14 § "Do not promise / later").

Modes to consider later (pattern from V, but without autofree):
manual (default) / arena / optionally marking individual functions.

---

## D2. Error model — DECIDED

**Choice: sum type `!T` + propagation operator + `or { }` block.**

```
let f = os.open(path)!          // propagate upward
let cfg = load(path) or {       // handle locally
    log.warn("missing: ${err}")
    Config.defaults()
}
```

Rejected:
- **Exceptions** — hidden control flow, breaks the overarching principle.
- **Go-style `(T, error)` pair** — clutters code with `if err != nil`.

Rationale: Zig and Rust converged on this independently.

In emission: `!T` is a struct with a tag. The propagation operator is `if (r.is_err)
return r;`. Zero overhead beyond checking the flag.

`error(n)` is a `!T` **value** ([132](../issues/132-match-else-or.md)): in a
function returning `!T` it is that return type; in a `match` expression a
success arm supplies the ok type. Both forms are valid:

```
fn color_name(c: Color): !str { … return error(1) … }

let s = match c {
    Color.Red { "red" }
    else { error(1) }
} or { "??" }
```

---

## D3. Generics — DECIDED

**Choice: `$fn` preprocessor. Not `[T]` in the compiler.**

Klin has generics. They expand **before** parse into ordinary `fn` /
`struct`. The checker never holds a type parameter. This is
intentional, not a gap — [04-macros.md](04-macros.md),
[language.md](language.md).

Nelua model: a powerful preprocessor generates specialized code.
Classes, generics, and polymorphism implemented ad hoc, without
putting `T` in the core.

```
$fn point(name: str, T: type) {
    pub struct $name { x: $T, y: $T }
    pub fn (p: $name) sqlen(): $T { return p.x*p.x + p.y*p.y }
}
$point("Vec2f", f64)
$point("Vec2i", i32)
```

Rationale: cheaper to implement than a full type system
with parameters; lets you defer the decision instead of making it
before the first line of the parser; monomorphization is anyway the only sensible
strategy with a C backend.

Risk: compile time, error messages from expanded macros.

**MVP (026):** [04-macros.md](04-macros.md) — before/after expand + example
[`examples/point.kl`](../examples/point.kl) /
[`point_macro.kl`](../examples/point_macro.kl).

**After 017 / 057:** `$fn` in stdlib is enough (`slice` / `slice_alloc`,
`mem.alloc_i32` / `alloc_u8`). Generics in the grammar — **not now**;
eventual thin sugar → same expand (variant 2) only when the pain is real.
Details: [034](../issues/034-generic-types.md). Still do not promise
`a.alloc(T, n)`.

---

## D4. Name mangling

Scheme: `module_Type_method`, e.g. `geom_Vec2_translate`.

**Must be exclusive.** On bare-metal symbol names must match
character-for-character with the vector table (`TIM2_IRQHandler`, `SysTick_Handler`).

```
@[isr("TIM2_IRQHandler")]
fn on_timer() { counter += 1 }
```

Mangling must be collision-resistant against everything from `<stdio.h>`
and against C keywords.

---

## D5. Method receivers

`fn (v: Vec2) len()` — copy. `fn (mut v: Vec2) translate()` — pointer.

**Mutation visible in the signature.** That is an improvement over Nelua, where
`function Vec2:translate` gives `self: *Vec2` implicitly and from the call
you cannot tell whether the object will be modified.

`mut` disappears in emission — only `*` remains. All immutability is a compile-time
phenomenon, zero runtime cost. **That is a good test for every feature:
if it does not disappear in emission, it probably breaks the overarching principle.**

A mutating method accepts any mutable place, not only a `let mut` name.
A place is mutable when it is a `let mut` local or a `mut` receiver, or
when it is reached through a `*mut` pointer — field and index chains
included (`(*c).err.lit(...)` where `c: *mut Ctx`). `&place` has type
`*mut T` when that place is mutable and `*T` when it is not. A place
reached only through a non-mut `*T` stays immutable, the same rule as
assignment (`(*p).x = …` already rejected a write through `*T`). A
slice element follows the place: `&s[i]` is `*mut T` when `s` is
mutable and `*T` when it is not. `xs[:]` is a view of the array, so
`&xs[:][i]` is `*mut` when `xs` is `let mut` or reached through `*mut`,
and `*T` when `xs` is immutable. An immutable binding (`let s = xs[:]`)
and a slice parameter stay `*T` even if the underlying array was
mutable. Assignment uses the same place: `s[i] = …`, `s[i] += …`, and
`s[i].field = …` through an immutable slice are checker errors
(`cannot assign through an immutable slice`). `let mut s = xs[:]` can
write, and `xs[:][i] = …` follows the array (`let mut xs` can write;
an immutable array cannot). A slice parameter is immutable; a function
that must write copies the header first (`let mut w = dst`). That copy
is the two words `{ptr, len}`, not the buffer. `&xs[:]` is not a place.
The call still passes a pointer; `mut` is not in the C.

---

## D6. Initialization — ZII

Variables declared without a value are zeroed (after Nelua).
No constructors or destructors (no RAII).
Optionally an annotation to disable zeroing for micro-optimization.

---

## D8. Bitwise operator precedence — DECIDED

**Choice: like Rust, not like C.**

```
* / %  →  + -  →  << >>  →  &  →  ^  →  |  →  comparisons  →  == !=
```

In C bitwise operators sit *below* comparisons, so `a & b == c` means `a & (b == c)` —
a classic trap. In Klin (like Rust) bitwise binds tighter:
`a & b == c` ⇒ `(a & b) == c`. Emission to C is still 1:1; parenthesization in
`BinaryExpr` preserves the intended order.

Binary `&` vs unary `&` (address) — distinguished by position, like `*`
(multiplication vs dereference).

Implemented in [078](../issues/078-bitwise-ops.md); example:
[`examples/bitwise.kl`](../examples/bitwise.kl). Combined table (with
`&&` / `||` / `or { }`): [guide.md](guide.md) §9.

---

## D9. Logical operators `&&` / `||` — DECIDED

**Choice: C-style `&&` / `||` on `bool` only; short-circuit; Rust-like tier above equality.**

```
error-or { }  →  ||  →  &&  →  == !=  →  comparisons  →  |  →  ^  →  &  →  …
```

- Both operands and the result are **`bool`** (same rule as `if` conditions —
  no numeric truthiness).
- Emission is 1:1 to C `&&` / `||` (short-circuit comes from the C compiler).
- Keyword `or` stays error-handling (`or { … }`, D2). No `and` / `or` aliases.
- Conditional value selection is already [`pick`](18-pick.md) /
  [085](../issues/085-pick.md) — not `? :`.

Without a `&&` token, `a && b` used to lex as `&` `&` and parse as
`a & (&b)` (bitwise AND of an address) — a silent trap. Lexing `&&` / `||`
as single tokens closes that hole.

Implemented in [097](../issues/097-logical-ops.md); example:
[`examples/logical.kl`](../examples/logical.kl). Combined table:
[guide.md](guide.md) §9.

---

## D10. Byte-string literal `b"..."` — DECIDED

**Choice: `b"fn"` has type `[]u8`.** The bytes of the text, plus `.len`.
Not a `str`.

`str` is `const char*`. Reading its bytes is explicit and read-only
(D22): `.len` is `strlen`, `s[i]` is one `u8`, and `cstr_u8` is a
read-only `[]u8`. Keyword tables, messages, and paths want counted
bytes, so they use `b"..."`. A second literal keeps `"..."` as `str`
and does not allocate.

- Escapes are the same as `"..."` (`\n` `\t` `\\` `\"` `\$` `\0`). No
  interpolation (`$` is a byte).
- `\0` is one NUL byte in both `"..."` and `b"..."`. It is not a
  multi-digit octal escape: `b"\00"` is a NUL followed by the character
  `0`. `"..."` accepts it because the two literals share one escape
  list. `str` is still `const char*`. `s.len` is `strlen` and stops at
  the first NUL (D22). `puts` does too. Counted bytes (a syscall path,
  a keyword table, an embedded NUL) use `b"..."`.
- Emission is a pointer at a static C string and an explicit length.
  The length is the number of bytes, including any embedded NUL. It is
  not `strlen`. The C literal spells that byte as `\000`, so a following
  digit is not swallowed. The extra NUL the C compiler appends is not
  part of `.len`.
- The bytes are read-only (C string-literal storage). The checker
  rejects a direct write (`b"fn"[0] = 1`, `KW[0] = 1` on a `[]u8`
  constant) and a write through an immutable slice (`let s = b"fn"`
  then `s[0] = 1`, or a `[]u8` parameter). A mutable slice cannot be
  bound to those bytes: `let mut s = b"fn"`, `let mut s = KW`,
  `let mut w = s` when `s` already points at them, and
  `for s := b"fn"`. A subslice is those same bytes: `let mut s =
  b"ab"[0:1]`, `b"ab"[0:]`, `b"ab"[:1]`, `KW[0:1]`, and `s[0:1]` when
  `s` already points at them. A mutable `[]u8` local cannot be assigned
  them either (`let mut s = xs[:]; s = b"fn"`). `pick`, `match`, and `or`
  count as read-only when any arm is, because the checker does not
  know which arm runs. Copy into a `[N]u8` to modify.
  An immutable module `let kw: []u8 = b"fn"` (or `= KW`) is those same
  bytes: `let mut w = kw` and `s = kw` are errors. A module
  `let mut s: []u8 = b"fn"` is assignable storage (D11); that
  initializer is accepted, and a write through `s` may crash.
  Not tracked, so a write can still fault at run time: a `[]u8`
  parameter (`fn f(s: []u8) { let mut w = s; w[0] = 1 }` then
  `f(b"fn")`), a function that returns `[]u8`, and a struct field
  (`row.kw = b"fn"`, then `row.kw[0] = 1` on a mutable struct).
- `.len` is the UTF-8 byte count.

```klin
let kw = b"fn"
printf("%d\n", kw.len)                 // 2
printf("%d\n", b"ab\0".len)            // 3
printf("%d\n", b"/proc/self/cmdline\0".len)  // 19
```

## D11. Module-level `const` and `let` — DECIDED

**Choice: `pub? const Name: Type = expression` is a compile-time value.
`pub? let` / `pub? let mut` at module scope is an object with an address.**

A keyword table, a page size, or a syscall number should be a named
value with no storage surprise. The initializer is the value; emission
is a C constant. A counter, a buffer, or a function pointer that the
program assigns is a global: `let` (not assignable) or `let mut`.

- Top level only. A local binding stays `let` (and a local shadows a
  constant of the same name in a value). A type still sees the constant.
- The type is required. Allowed: an integer prim (`i8`…`i64`, `u8`…`u64`,
  `usize` / `isize`, `int`), `bool`, or `[]u8`.
- `bool` is `true` / `false`. `[]u8` is `b"..."`. Not a float or a `str`.
- An integer initializer is an integer constant expression: literals
  (hex, binary, octal, underscores, `'A'`), unary `-` and `~`, the
  operators `+ - * / % << >> & | ^`, and names of other integer
  constants, including `mod.NAME` after `import`. A constant may name
  one declared later in the program. A cycle is an error (constant
  `A` depends on itself). A named constant must have that same integer
  type; a different type is a type mismatch. `~x` on a value
  that is not a constant is not folded — it stays a runtime expression.
- Each literal and each operator result is checked against the
  constant's declared type with the D12 diagnostic. Overflow is that
  error, not a wrap. Division by zero and remainder by zero are errors.
  A shift by a negative count, or by a count greater than or equal to
  the type's width, is an error. The shift count is the same integer
  type as the constant, so `const X: u8 = 1 << -1` fails the range check
  on `-1` before the negative-shift check. Precedence is the language
  precedence (`*` `/` `%` tighter than `+ -`, tighter than `<<` `>>`):
  `1 << 2 + 1` is `1 << 3`. Subexpressions are not wrapped, so
  `const X: i8 = -128` fits and `const X: i8 = 0 - 128` does not (`128`
  is out of range for `i8`).
- Emission keeps the source spelling of a lone literal and of unary
  `-` / `~` on a literal (`0x4`, `'A'`, `~0`, `-128`) when that spelling
  is a valid C constant. A folded expression is a decimal. A value above
  `2^63-1` is emitted with a `ULL` suffix; `i64` / `isize` minimum is
  `(-9223372036854775807LL - 1)`. The same two forms are used when that
  literal is coerced in an expression
  (`let x: u64 = 18446744073709551615`,
  `let x: i64 = -9223372036854775808`), so the generated C does not
  contain a decimal that does not fit in a signed 64-bit constant.
  Not a C `enum` and not `constexpr`.
- The C name is `module_NAME`. `pub` emits `const`, private emits
  `static const`. All modules share one `.c`, so visibility is enforced
  by the checker (`mod.NAME` on a private constant is an error), not by
  C linkage.
- An integer constant expression is a valid `[N]T` length: `[N]T`,
  `[mod.NAME]T`, `[N * 2]T`, `[1 + 2]T`, in a local, a struct field, or
  a parameter. The bound stored on the type is the folded integer,
  written in C as a decimal (a C `const` variable is not an integer
  constant expression; naming it in the bound would make a VLA and
  would be illegal as a struct field). `0x1000` and `'A'` used as a
  length become that decimal. Named constants in one length share one
  integer type; a length made only of literals folds as `i32`. A
  `bool`, a `[]u8`, a negative value, or a value above `2^63-1` is an
  error (array length is too large, for the last). A local of the
  same name does not change the length — a type resolves the module
  constant. A local alone is not a length.
- `NAME = …` and `NAME[i] = …` on a `[]u8` constant are checker errors.
  `let s = NAME` copies the `{ptr, len}` header; `s` points at the same
  read-only bytes, and `let mut s = NAME` is the D10 error.

```klin
pub const PAGE: i64 = 4096
const TWICE: i64 = PAGE / 2
const KW: []u8 = b"fn"

fn main() {
    let buf: [PAGE]u8
    let half: [TWICE]u8
    printf("%d %d %d\n", cast(i32, PAGE), KW.len, half.len)
}
```

### Module-level `let`

`const` does not name storage. It cannot be the operand of `&`, and it
is not an object another global can point at. `let` is that object.
Immutable `let` exists beside `const` for that reason: `let limit: i32
= PAGE` has an address, `const PAGE` does not. `let` is not assignable
and `&limit` is `*i32`. `let mut` is assignable and `&n` is `*mut i32`.

- Top level only. `:=` is not a module declaration (it stays the local
  sugar for `let mut`). The type is required (`let mut n: i32 = 1`).
  One name per declaration.
- Allowed types: an integer or float prim, `bool`, `str`, an enum, a
  struct, a pointer, a slice, a function pointer, and `[N]T` of those.
  `!T` is not a global (`a global cannot have type …`).
- The initializer is optional. Omitting it zero-initializes, the same
  values as a local without an initializer (integer `0`, `false`,
  `NULL`, `{0}`, a slice `{ NULL, 0 }`, an enum `0`). A function
  pointer's zero is the integer `0`, not `NULL`: ISO C does not convert
  `void *` to a function pointer.
- When present, the initializer must be a constant expression. Allowed:
  literals (including `b"..."`), `const` names (`N`, `mod.NAME`),
  integer constant expressions (the same operators as a `const`),
  float arithmetic of constant floats, array and struct literals of
  those, an enum variant, `cast` of a constant to a pointer, prim, or
  enum, the address of a global, a `const`, a function, a field, or a
  constant index of a global array, `xs[:]`, `xs[a:b]`, `xs[a:]`, and
  `xs[:b]` of a global array when `a` and `b` are constant expressions,
  and a function name (a function-pointer initializer, including
  `mod.func`).
  A global's value is not a constant — C cannot copy that object into
  static storage. A non-constant initializer is
  `global initializer must be a constant expression`.
- A name used in the initializer is emitted as that constant's own
  value (the folded decimal, the source spelling, or the `[]u8` brace),
  not as the C object. `static int x = PAGE` is not a constant
  initializer. Aggregate initializers are brace lists, not compound
  literals.
- A global is not an `[N]T` length. The length is still a `const` or a
  literal expression.
- Assignment, compound assignment (`+=` and the rest), and the `for
  name = …; …; name += …` header follow the same mutability as a local.
  A field, an index, and `*p` do too. A `mut` method accepts a `let mut`
  global. Writing an immutable global is `cannot assign to immutable
  variable`.
- `pub let` / `pub let mut` is `mod.name` after `import`. Another module
  may assign `mod.name` only when the global is `pub let mut`. `pub let`
  is readable and not writable. Private is `static` in C and is neither
  readable nor writable from another module (the diagnostic names
  `mod.name` and says the global is private). There is no generated
  setter. `mut` is a property of the
  storage; `pub` is visibility. The checker is the gate, because the
  whole program is one `.c`.
- A local of the same name shadows the global in a value. A global of
  the same name as an import qualifier shadows that qualifier in a
  value (`let mut os: i32` then `os.PAGE` is not the imported constant).
  A type still sees the module constant, as it does for a local.
- The C name is `module_name`, the same prefix as a free function.
  Every global is declared before any initializer, so a later global
  can be named (`let mut p: *mut i32 = &later` above `later`).
  Prototypes are emitted before globals, so a function-pointer
  initializer can name a function. Typedefs for structs, slices, and
  function returns are emitted before both.
- No attributes on a global. A global must not reuse the name of a
  `const`, a type, or a free function in the same module.
- An immutable `[]u8` global initialized from `b"..."` or a `[]u8`
  const is read-only storage (D10). `let mut w = kw` and `s = kw` are
  errors. A mutable global slice is not: `let mut s: []u8 = b"..."` and
  `let mut s: []u8 = xs[:]` of an immutable array are accepted, and a
  write may crash. Copy into a `[N]u8` to modify.
- Async functions and threads share the global the way C does. There is
  no atomics, no lock, and no implicit synchronization. A data race is
  the program's.

```klin
let mut n: i32 = 1
let limit: i32 = PAGE
let mut buf: [8]u8
let mut p: *mut i32 = &n

fn main() {
    n = n + limit
    *p += 1
}
```

## D12. Integer literal range — DECIDED

An untyped integer literal that is coerced to a declared integer type
must fit that type. `const X: u8 = 300` and `let x: u8 = 300` are
checker errors, not a silent wrap to `44`. The diagnostic names the
type and the inclusive range (`u8` is `0..=255`, `i8` is `-128..=127`).

The same check covers hex (`0x12C`), binary, octal, underscores,
character literals (`'A'` is 65; character literals are ASCII), and a
negative literal (`const X: u8 = -1`). It applies wherever that literal
is coerced to a declared integer type: `const`, `let`, a parameter, a
return, a struct field, an array element, an enum variant
(`enum E: u8 { A = 300 }`). An array literal takes the element type of
the array it is coerced to: `let a: [2]u8 = [1, 2]`, a struct field,
and a parameter. Each element is range-checked, so
`let a: [2]u8 = [1, 300]` is the `u8` error. With no expected array
type, `let a = [1, 2]` is still `[2]i32`. A length mismatch names that
default (`got [2]i32`). An element that is an integer constant
expression folds in the element type (`let a: [1]u8 = [1 + 2]` is
`[1]u8`; `let a: [1]u8 = [200 + 100]` is the `u8` range error). A
function may return `[N]T` (D13); the literal in that `return` uses the
declared element type. The implicit next
value is checked too: `enum E: u8 { A = 255, B }` is an error because
`B` would be 256. The message names the variant, the value, the base
type, and the inclusive range. The counter after the last variant is
not an error.

An empty array literal `[]` is a zero-length array from the same
context as any other array literal: `let a: [0]u8 = []`, an argument
of `[0]T`, and a struct field. `let a: [1][0]u8 = [[]]` types the
inner `[]` as `[0]u8`. With no array type (`let a = []`, or
`let x: u8 = []`) the error asks for one, for example `[0]u8`. A
non-zero length says the literal has length 0 (`let a: [2]u8 = []`).
The C is a zero-size array (`uint8_t a[0] = { }`), the same GCC
extension as a written `[0]u8` local; `gcc -std=c11 -pedantic-errors`
rejects it (`ISO C forbids zero-size array`). A function still cannot
return `[0]T` (D13).

`cast(u8, 300)` is still a C truncation. The check is the coercion,
not the cast.

Widths are the fixed integer widths. `int` is `i32`. `usize` / `isize`
use a 64-bit range, matching LP64 `size_t` / `ptrdiff_t` in host
emission.

An integer constant expression — literals, integer `const` names, unary
`-` / `~`, and `+ - * / % << >> & | ^` — takes the expected integer
type wherever a literal does: `let`, a parameter, a `return`, a struct
field, an array element. `let x: u8 = 1 + 2` is `u8` (the value `3`).
`let x: u8 = 200 + 100` is the same range error as `300` (`0..=255`).
`let a: [1]u8 = [1 + 2]`, `take(1 + 2)`, `return 1 + 2`, and
`Pair{ n: 1 + 2 }` fold the same way. `pick` and `match` arms that are
still untyped adopt that type too (`let x: u8 = pick c { 1 + 2 } { 4 }`,
`let x: u8 = match k { 0 { 1 + 2 } else { 4 } }`, and
`let row: [2]u8 = match k { 0 { [1, 2] } else { [3, 4] } }`).
`let x: u8 = match k { 0 { 300 } else { 1 } }` is the `u8` range error.
A `match` success arm next to `error(n)` stays open, so
`let x: u8 = match k { 0 { 1 + 2 } else { error(1) } } or { 4 }` folds
in `u8`. A concrete fallback (`or { n }` where `n` is already `i32`)
fixes that arm as `i32`. With no expected type the arm is still `i32`
(`let x = match k { 0 { 1 + 2 } else { 4 } }`). Rules match a `const`
initializer (D11):
subexpressions are not wrapped (`let x: i8 = 0 - 128` is an error
because `128` does not fit `i8`), a named constant must already have
that integer type, division or remainder by zero is an error, and a
shift by a negative count or by a count at least as wide as the type
is an error. With no expected type the expression is still `i32`
(`let x = 1 + 2`). `puts` and `printf` have no parameter types, so an
untyped argument uses that default: `printf("%d\n", 1 + 2)` folds to
the `i32` value `3`, and a literal that does not fit `i32` is the range
error. An untyped float becomes `f64` and is not an integer fold.
A float expected type adopts it the way a lone
literal does (`let x: f64 = 1 + 2`); that is not an integer fold.

Unary `-` and `~` on an integer literal, or on an integer constant
expression, stay untyped until that type is known: `let x: i64 = -1`,
`let x: i64 = (-1) << 2`, `take(-1)` when the parameter is `i64`,
`const M: u32 = ~0`. The range check applies to the result, so `-128`
fits `i8` and `-129` does not, and `-1` does not fit `u8`. `~` is the
complement in that type's width: the operand must fit, and `~0` as
`u32` is `4294967295`. An expression that names a variable stays
runtime (`let x: u8 = y + 1`, `~x`). Emission of a folded operator is
the decimal (the same portable forms as a folded `const`: `ULL` above
`2^63-1`, and `(-9223372036854775807LL - 1)` for `i64` / `isize`
minimum). A lone literal, unary `-` / `~` on a literal, and a lone
constant name keep their spelling.

## D13. Returning `[N]T` — DECIDED

C cannot return an array by value. A function that returns `[N]T`
returns a struct with one array field `v`:

```c
typedef struct { uint8_t v[2]; } klin_arr2_u8;

klin_arr2_u8 pair(void) {
    klin_arr2_u8 klin_ret_0 = (klin_arr2_u8){ .v = { 1, 2 } };
    return klin_ret_0;
}
```

No allocation and no loop. The copy is that struct return. A nested
array is one struct (`[1][2]u8` is `uint8_t v[1][2]`), not a wrapper
around a wrapper. The field name is `v`. This is not a C enum and not
`constexpr`.

A local initialized from a literal stays a C array
(`uint8_t a[2] = { 1, 2 }`). A local initialized from a call stores the
struct; Klin `a[0]` is `a.v[0]` in C. Passing that local, or the call,
to a `[N]T` parameter passes `.v` (the parameter stays a C array and
decays to a pointer). `let b = a` copies the struct when `a` came from
a call. Returning a C array variable copies each element into `.v` in
the return statement (`{ a[0], a[1] }`). An index expression is not
returned directly (`return a[i]` asks to bind the row first) so the
index is not evaluated twice. A struct field copied from a call,
`pick`, or `match` evaluates that value once into a temporary, then
copies `tmp.v[i]` — the call is not repeated per element. A field
copied from a variable stays `a.v[0], a.v[1]`.

`let [x, y] = pair()` uses that same temporary: the call runs once,
then the bindings are `tmp.v[0]` and `tmp.v[1]`. `pick` and `match`
do too (`match` assigns the temporary inside each arm). A name and a
literal stay element reads and do not build the wrapper.

An array literal in `return` takes the element type from the
declaration (`fn pair(): [2]u8 { return [1, 2] }`). `return [300]` is
the `u8` range error. `return [1 + 2]` folds (D12).

A zero-length array is not returned: `uint8_t v[0]` is not ISO C
(`fn f(): [0]u8` and `fn(): [0]u8` are errors). `pick` and `match`
cannot produce one either (`let a: [0]u8 = pick true { [] } { [] }`,
the same for `match`, and a nested `[1][0]u8`). The wrapper would be
`uint8_t v[0]`, which is not ISO C. A literal local stays the GCC
extension (`let a: [0]u8 = []`, D12).
`![N]T` stays invalid.
`async fn` still returns void. A struct field cannot be a function
type that returns an array of structs — the wrapper needs that struct
to be complete. A parameter or a local of that function type is fine.

## D14. Slice element type — DECIDED

**Choice: `[]T` is `{ T *ptr; size_t len; }` for any value `T` C can point at.**
Not only a primitive.

`[]Token`, `[]str`, `[][]u8`, `[]*T`, `[]fn(i32): i32`, and `[][N]u8`
are the same two-word header as `[]i32`. No allocation, no capacity,
no bounds check (an index is still a C index). `.len` is the header's
`len`. `s[i].field` is `s.ptr[i].field`.

- Allowed elements: a primitive, a struct, an enum, `str`, a pointer,
  a slice, a function pointer, or an array whose element is one of
  those and is not itself a struct.
- `xs[:]` on `[N]Token` has type `[]Token`. The pointer is the array
  (it decays to `struct Token *`). `rows[i][:]` on `[N][M]Token` is
  `[]Token` — one row. A slice whose element is the row array
  (`[][M]Token`, or `rows[:]`) is rejected: the slice typedef would
  need `Token` complete, and a struct that stored that slice would
  need the typedef first.
- `[]!T` and `[]void` are errors.
- Writes and `&s[i]` follow the slice place (D5). `let mut s = xs[:]`
  can write `s[i].field`. An immutable binding and a slice parameter
  cannot. `&s[i]` is `*mut T` when that place is mutable and `*T`
  when it is not.
- The C typedef is `klin_slice_<element>`. A struct element uses the
  struct tag (`struct mod_Token *ptr`) so the typedef can come before
  the struct body. `struct Node { kids: []Node }` is that order.
  A nested slice is `klin_slice_slice_u8` (the inner typedef first).
  A slice of a function pointer is emitted after that function typedef.

```klin
struct Token {
    kind: i32
    n: i32
}

fn sum_kind(xs: []Token): i32 {
    let mut i = 0
    let mut acc = 0
    while i < xs.len {
        acc = acc + xs[i].kind
        i = i + 1
    }
    return acc
}
```

## D15. Subslice — DECIDED

**Choice: `xs[a:b]`, `xs[a:]`, and `xs[:b]` are a header. No runtime bounds check.**

Same policy as indexing. Issue 007 considered a check and did not add
one; a subslice does not add a hidden branch either. `a` and `b` are
integers, or an enum used the same way as an array index (it must fit
a fixed array; a slice rejects it). The pointer is `base + a` (`base`
when `a` is omitted). The length is `b - a`, or `len - a` when `b` is
omitted, or `b` when `a` is omitted. Each bound is converted to
`size_t` so the header field stays `size_t`. Out of range, `a > b`,
and a negative bound are undefined behavior — not a Klin error and
not a check in the generated C.

The result is `[]T` over the same elements. Mutability follows the
source place (D5), including through another subslice: `let mut xs`
makes `xs[a:b][i] = …` a write; an immutable binding, a slice
parameter, a byte-string literal, and a `const` do not. `&xs[a:b][i]`
is `*mut T` or `*T` by that same place. A subslice of read-only bytes
is those bytes (D10): `let mut s = b"ab"[0:1]` (also `[0:]`, `[:1]`,
a `[]u8` const, and a binding that already points at them) is an
error, not a mutable header. `let s = b"ab"[0:1]` stays legal and is
itself read-only. A `[]u8` parameter's subslice is not tracked.

An array subslice needs an l-value, the same rule as `xs[:]`. A slice
`s[:]` is that header. `s[a:]` reads the pointer and the length. When
the source is not a plain place, or the start is not a plain place or
an integer literal, C is one call to `klin_slice_tail_*`. That call is
an expression, so a `while` or `for` condition evaluates it on every
check, and the start bound is a single argument. A plain `xs[1:]`
stays inline (`base + a`, `len - a`). `s[:b]` and `s[a:b]` read only
the pointer. Two calls in one tail (`take(xs)[step():]`) each run
once; C does not sequence the helper's two arguments.

```klin
fn main() {
    let mut xs: [5]i32 = [10, 20, 30, 40, 50]
    let mut mid = xs[1:4]
    mid[0] = 7
    printf("%d %d\n", mid.len, xs[1])
}
```

## D16. Function field call — DECIDED

**Choice: `h.cb(1)` calls a function-typed field. A method of the same name conflicts.**

The parser already treats `name(` on the same line as a call. The checker decides what it calls:

- A method and no function field of that name: the method, as before.
  A field that is not a function does not hide the method (`n: i32` and
  `fn (b: Box) n()` — `b.n()` is the method, `b.n` is the field).
- A function field and no method: the call is `h.cb(1)` in C (the field
  is a function pointer). `(*p).cb(1)` is the same. There is no
  auto-deref (`p.cb` on a `*Holder` is still not a method call) and no
  `s[i](…)` postfix. Calling does not require the place to be mutable.
- Both a method and a function field, including a private method:
  `ambiguous call \`cb\`: \`Holder\` has both a method and a function field of that name`.
- A field that is not a function, and no method:
  `field \`cb\` has type \`i32\`, not a function`.
- Neither: `type \`Holder\` has no method \`cb\``.

```klin
struct Holder {
    cb: fn(i32): i32
}

fn inc(x: i32): i32 { return x + 1 }

fn main() {
    let h = Holder{ cb: inc }
    printf("%d\n", h.cb(1))
}
```

## D17. Pointer and integer cast — DECIDED

**Choice: `cast` between a pointer and an integer goes through `uintptr_t` or `intptr_t`.**

`stdint.h` is already included. The cast is the only conversion; there is
no pointer arithmetic (`p + 1` is not a pointer add).

- Pointer → unsigned (`usize`, `u8`…`u64`): `(target)(uintptr_t)ptr`.
- Pointer → signed (`isize`, `i8`…`i64`): `(target)(intptr_t)ptr`.
  A narrower target truncates, like any other numeric cast.
- Unsigned, untyped integer, or pointer → pointer: `(T *)(uintptr_t)…`
  (unchanged).
- Signed integer → pointer: `(T *)(intptr_t)…`.
- Not a float, not `bool`, not a function pointer. `cast(f64, &x)` is
  `cast from a pointer requires an integer type`.

```klin
fn main() {
    let mut x: i32 = 42
    let a = cast(usize, &x)
    let p: *mut i32 = cast(*mut i32, a)
    *p = 7
    printf("%d\n", x)
}
```

## D18. `main` arguments — DECIDED

**Choice: `fn main()` or `fn main(args: []str)`. Not `[][]u8`.**

`[]str` is the argv pointer and the count. One cast from `char **` to
`const char **`, no loop, no allocation. `[][]u8` would measure every
argument (`strlen`) and build a slice per argument — hidden work, so
it is not the signature. A program that wants the bytes of one
argument writes `args[i].len`, `args[i][j]`, or `cstr_u8(args[i])`
(D22). That walk is not part of entering `main`. Kliner can still
read `/proc/self/cmdline`; the language path is this parameter.

`args.len` is `argc`, including `argv[0]`. The slice is immutable
(a parameter, D5). A negative `argc` is not checked; the host does
not pass one. C parameters are `klin_argc` and `klin_argv`. When
either name is already bound in `main` (the parameter, or a local,
including one inside `or`), the next free pair is
`klin_main_argc` / `klin_main_argv`, then `klin_argc_2` /
`klin_argv_2`. `main()` with no parameters stays `int main(void)`.
`async fn main` stays rejected.

```klin
fn main(args: []str) {
    printf("%d\n", cast(i32, args.len))
}
```

## D19. Pointer to an array — DECIDED

**Choice: `*[N]T` and `*mut [N]T` are a C pointer to the array, `T (*)[N]`.**

`(*p)[:]`, `(*p)[a:b]`, `(*p)[a:]`, and `(*p)[:b]` are `[]T` for every
element a slice allows (D14): a primitive, a struct, an enum, `str`, a
pointer, a slice, a function, or an array that is not an array of
structs. `[]Token` and `[][]u8` can be carved from a buffer without a
helper per type. `(*p)[i]` indexes that array. There is no runtime
bounds check (D15).

`*mut [N]T` is a mutable place. `*[N]T` is an immutable place.
`(*p)[i] = …` and `(*p)[:][i] = …` follow that place. `let mut s =
(*p)[:]` is a new binding: it can write even when `p` is `*[N]T`, the
same as `let mut s = xs[:]` on an immutable array. A cast is not
tracked. Read-only bytes stay read-only (D10): a `b"..."` subslice
still cannot be bound with `let mut`.

`p` may be a local, a parameter, a struct field, a global, or a call.
`(*get())[:]` evaluates the call once. `&` of a `[N]T` returned by
value (a local holding that return) is the address of the array inside
the wrapper, so the pointer type stays `T (*)[N]`. `cast` between that
pointer and an integer still goes through `uintptr_t` / `intptr_t`
(D17).

These forms are a checker error, not broken C:

- `p[:]` or `p[i]` on the pointer itself (it is not an array or a slice).
- A struct field whose C typedef would need an array of structs to be
  complete (`[]*mut [N]Token`, `fn(): *mut [N]Token`, `!*mut [N]Token`).
  A field `buf: *mut [N]Token` is the pointer, written inline, and is
  allowed.
- A field that needs its own struct, or a cycle of structs, to be
  complete (`kids: *mut [N]Node`, two structs each holding an array of
  the other). `next: *Node` and `kids: []Node` stay valid.
- A slice range inside `async fn` (the async MVP has no slice range).
  `(*p)[i]` in an async function is allowed.

```klin
fn main() {
    let mut buf: [4]Token = [Token{ kind: 1, n: 0 }, Token{ kind: 2, n: 0 }, Token{ kind: 3, n: 0 }, Token{ kind: 4, n: 0 }]
    let p = cast(*mut [4]Token, cast(usize, &buf))
    let mut s = (*p)[1:3]
    s[0].n = 9
    printf("%d\n", buf[1].n)
}
```

## D20. Free functions inside `$fn` — DECIDED

**Choice: a plain free function is private to one expansion. Its name is `name__<macro>_<file>_<n>`.**

A second `$vec(B, u8)` after `$vec(A, i32)` used to redeclare `fn helper`.
Emitting the helper once when the text matches does not work: the two
bodies differ because `$T` was substituted. The expanded name is not a
stable API. Call the helper with the spelling in the template
(`helper(v)`).

A name is plain when the template has `fn helper` at brace depth 0.
These are not renamed:

- `fn (v: T) get` — a method
- `fn Type.name` — an associated function
- `fn each_$T`, `fn helper$T`, `fn task_$name` — a `$` splice is the
  public name (`task_blink`, `id_i32`)

Two expansions that produce the same spliced name are still a
redeclaration. That is the caller's spelling, not a hidden copy.

After the parameters are substituted, every identifier with a plain
helper's spelling in that expansion is rewritten. A field, a parameter,
a method, and the block argument stay consistent with the function.
Strings, `//` comments, and an identifier written after `$` (a nested
macro, or a splice that is still open) are not rewritten. The count starts at 1 for
each macro in that file. The file part is the last path segment without
`.kl`, keeping identifier characters (`<input>` is `input`). An empty
stem is `kl`. A stem that would start with a digit is prefixed with `f`.

```klin
$fn note(T: type) {
    fn helper(v: $T): $T { return v }
}
$note(i32)
$note(i32)
```

In `t.kl` that is `helper__note_t_1` and `helper__note_t_2`.

## D21. An `or` block may diverge — DECIDED

**Choice: the block ends with a value, or every path leaves with `return`, `break`, or `continue`.**

`let n = parse() or { return }` is the same shape as `or { 0 }`. The
expression type is the ok type of the `!T`. The diverging path does not
have to match that type. `return` is checked against the enclosing
function:

- void: bare `return`. `return value` is `void function cannot return a value`
- a function that returns `T`: `return value` of that type. A bare
  `return` is `function … must return T`
- `!T`: `return error(n)`, or `return` of that `!T`. A bare `return`
  is still `must return !T`
- in a function that does not return `!T`, `return error(n)` is
  `type mismatch: expected i32, got error` (the `error` type)

`break` and `continue` count only when they leave the `or`. A `break`
inside an inner loop does not. `if` / `else`, including `else if`, both
have to diverge. `if` without `else` does not. A nested block may.
`match` uses the same exhaustiveness as a returning `match` (`else`, or
every enum variant with no `when`), and every arm diverges. A `match`
whose arms are statements is that statement. A `match` whose arms are
values is still a match expression, so it is only legal when the `or`
itself is a `let` or an assignment (the existing match-expression rule). `while true`
(the literal `true` only) and `for ;;` diverge when the body does, seen
from inside that loop. `while true { break }` does not: the `break`
leaves the `while`, then the `or` falls through. `while 1 == 1` is not
treated as always true.

`expr!` is unchanged. It still needs a function that returns `!T`.
`err: i32` is still in scope in the block. `pick` still cannot contain
`or` (it is a C `?:`). An empty block, or a block that can fall
through, is:

`` `or` block must end with a value, or diverge with `return`, `break`, or `continue` ``

The block is an expression. The form is `let n = f() or { return }`,
not a bare statement.

```klin
fn take(ok: bool): !i32 {
    if ok { return 7 }
    return error(3)
}

fn use(ok: bool): i32 {
    let n = take(ok) or { return err }
    return n
}
```

## D22. Reading `str` — DECIDED

**Choice: `s.len` and `s[i]` on the pointer, plus `cstr_u8(s)` when the code wants a `[]u8`. All three are read-only.**

`str` stays `const char*` (D10). `main(args: []str)` still does not
measure each argument (D18). The walk happens only where the program
writes it.

- `s.len` has type `i32`, the same as a slice `.len`. Emission is
  `(int32_t)strlen(…)`. Every evaluation walks from the pointer to the
  first NUL. There is no cache and no allocation. A string longer than
  2^31−1 truncates. It is not a constant, so it cannot be an `[N]T`
  length. `b"ab\0".len` is 3 (the NUL counts). `"ab\0c".len` is 2
  (`strlen` stops). `s.len = 1` is `` `len` is read-only ``. Any other
  field is `` `str` has no field `foo` (`.len` is the byte length; `cstr_u8` builds a read-only `[]u8`) ``.
- `s[i]` has type `u8`. No bounds check (D15). Emission is
  `((uint8_t *)(…))[i]`, so a byte above 127 is not a negative `char`.
  Assignment is `` cannot assign through a string (`str` is read-only) ``.
  `&s[i]` is `*u8` even when the `str` variable is `mut`: the pointer
  can be reseated, the byte cannot. There is no `s[a:b]`
  (`` `str` has no subslice; `cstr_u8(s)` is a read-only `[]u8` ``).
- `cstr_u8(s)` is a builtin of type `[]u8`. The argument is evaluated
  once: one pointer temporary, one `strlen`, one slice header. The
  bytes are read-only (D10), so `let mut w = cstr_u8(s)`, assigning
  `cstr_u8(p)` into a mutable `[]u8`, and `let mut p = cstr_u8(s)[0:1]`
  are errors. A user `fn cstr_u8` in scope hides the builtin.
  `mod.cstr_u8` is that module's function, not the builtin.
- `#include <string.h>` is emitted only when the program uses `s.len`
  or `cstr_u8`. Indexing a `str` does not need it.
- A NULL `str` is undefined behavior, the same as `strlen` in C. There
  is no runtime check.
- `cast` of a `str` to an integer stays rejected (D17).
- `stdlib` `str.len` still returns `usize` and still needs
  `import str`. Language `s.len` is `i32` and needs no import. Both
  are a `strlen` call. `==` on `str` stays unsupported
  ([080](../issues/080-stdlib-str.md)): the cost does not disappear,
  so it is not an operator. `s.len` spells that cost as a call.

```klin
fn main(args: []str) {
    if args.len > 1 {
        let s = args[1]
        printf("%d %d\n", s.len, s[0])
        let b = cstr_u8(s)
        printf("%d\n", cast(i32, b.len))
    }
}
```

## D7. To decide later

- Closures — at all? Nelua does not have them outside top-level. A struct
  with environment + function pointer is medium difficulty, but allocating
  the environment breaks the overarching principle.
- Interfaces — fat pointer `{ void* data; Vtable* vt; }`. If so,
  dynamic dispatch is **explicit** in syntax (`dyn Writer`), static by default.
- Slice: `struct { T* ptr; size_t len, cap; }` — forces generics, so
  it depends on D3.
- Operators on user types — at all. Risk of hidden cost.
