# Design decisions

This is the decision log (D1–D13), not an introduction. Start with
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

`str` is `const char*` — a C string, no length, no indexing. Keyword
tables, messages, and paths want the bytes. A second literal keeps
`"..."` as `str` and does not allocate.

- Escapes are the same as `"..."` (`\n` `\t` `\\` `\"` `\$` `\0`). No
  interpolation (`$` is a byte).
- `\0` is one NUL byte in both `"..."` and `b"..."`. It is not a
  multi-digit octal escape: `b"\00"` is a NUL followed by the character
  `0`. `"..."` accepts it because the two literals share one escape
  list. `str` is still `const char*` with no length, so `puts` and
  other C string operations stop at the first NUL. Counted bytes
  (a syscall path, a keyword table) use `b"..."`.
- Emission is a pointer at a static C string and an explicit length.
  The length is the number of bytes, including any embedded NUL. It is
  not `strlen`. The C literal spells that byte as `\000`, so a following
  digit is not swallowed. The extra NUL the C compiler appends is not
  part of `.len`.
- The bytes are read-only (C string-literal storage). The checker
  rejects a direct write (`b"fn"[0] = 1`, `KW[0] = 1` on a `[]u8`
  constant) and a write through an immutable slice (`let s = b"fn"`
  then `s[0] = 1`, or a `[]u8` parameter). `[]u8` has no read-only
  flavor on a mutable place: `let mut s = b"fn"` then `s[0] = 1`
  still compiles and can crash at run time. Copy into a `[N]u8` to
  modify.
- `.len` is the UTF-8 byte count.

```klin
let kw = b"fn"
printf("%d\n", kw.len)                 // 2
printf("%d\n", b"ab\0".len)            // 3
printf("%d\n", b"/proc/self/cmdline\0".len)  // 19
```

## D11. Module-level `const` — DECIDED

**Choice: `pub? const Name: Type = expression`.** Immutable. No mutable
globals, and no `let` at module scope.

A keyword table, a page size, or a syscall number should be a named
value with no storage surprise. The initializer is the value; emission
is a C constant.

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
  read-only bytes (see D10).

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
(`let x = 1 + 2`). A float expected type adopts it the way a lone
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
(`fn f(): [0]u8` and `fn(): [0]u8` are errors). A `pick` or `match`
whose result is `[0]T` is still stored in that wrapper
(`let a: [0]u8 = pick true { [] } { [] }`). It is the same GCC
extension as `let a: [0]u8 = []` (D12), not a function return.
`![N]T` stays invalid.
`async fn` still returns void. A struct field cannot be a function
type that returns an array of structs — the wrapper needs that struct
to be complete. A parameter or a local of that function type is fine.

## D7. To decide later

- Closures — at all? Nelua does not have them outside top-level. A struct
  with environment + function pointer is medium difficulty, but allocating
  the environment breaks the overarching principle.
- Interfaces — fat pointer `{ void* data; Vtable* vt; }`. If so,
  dynamic dispatch is **explicit** in syntax (`dyn Writer`), static by default.
- Slice: `struct { T* ptr; size_t len, cap; }` — forces generics, so
  it depends on D3.
- Operators on user types — at all. Risk of hidden cost.
