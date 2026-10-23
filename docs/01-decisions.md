# Design decisions

This is the decision log (D1–D11), not an introduction. Start with
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
assignment (`(*p).x = …` already rejected a write through `*T`). The
call still passes a pointer; `mut` is not in the C.

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
- The bytes are read-only (C string-literal storage). The checker only
  rejects a direct write: `b"fn"[0] = 1` and `KW[0] = 1` on a `[]u8`
  constant. A write through a copy (`let s = b"fn"` then `s[0] = 1`) or
  through a `[]u8` parameter compiles and crashes at run time — `[]u8`
  has no read-only flavor. Copy into a `[N]u8` to modify.
- `.len` is the UTF-8 byte count.

```klin
let kw = b"fn"
printf("%d\n", kw.len)                 // 2
printf("%d\n", b"ab\0".len)            // 3
printf("%d\n", b"/proc/self/cmdline\0".len)  // 19
```

## D11. Module-level `const` — DECIDED

**Choice: `pub? const Name: Type = literal`.** Immutable. No mutable
globals, and no `let` at module scope.

A keyword table, a page size, or a syscall number should be a named
value with no storage surprise. The initializer is the value; emission
is a C constant.

- Top level only. A local binding stays `let` (and a local shadows a
  constant of the same name in a value). A type still sees the constant.
- The type is required. Allowed: an integer prim (`i8`…`i64`, `u8`…`u64`,
  `usize` / `isize`, `int`), `bool`, or `[]u8`.
- The initializer is a literal: an integer (including `-N`, hex, `'A'`),
  `true` / `false`, or `b"..."`. Not `1 + 2`, not another constant, not
  a float or a `str`.
- The C name is `module_NAME`. `pub` emits `const`, private emits
  `static const`. All modules share one `.c`, so visibility is enforced
  by the checker (`mod.NAME` on a private constant is an error), not by
  C linkage.
- An integer constant is a valid `[N]T` length: `[N]T` and `[mod.NAME]T`,
  in a local, a struct field, or a parameter — the same positions as a
  literal length. The bound is the constant's integer value, written in
  C as a decimal integer constant expression (the same form as a literal
  length, so `0x1000` and `'A'` become their numeric values). A C
  `const` variable is not an integer constant expression; naming it in
  the bound would make a VLA and would be illegal as a struct field.
  A `bool`, a `[]u8`, or a negative constant is an error. A local of
  the same name does not change the length — a type resolves the module
  constant. A local alone is not a length.
- `NAME = …` and `NAME[i] = …` on a `[]u8` constant are checker errors.
  `let s = NAME` copies the `{ptr, len}` header; `s` points at the same
  read-only bytes (see D10).

```klin
pub const PAGE: i64 = 4096
const KW: []u8 = b"fn"

fn main() {
    let buf: [PAGE]u8
    printf("%d %d %d\n", cast(i32, PAGE), KW.len, buf.len)
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
return, a struct field, an array whose element type is already that
integer, an enum variant (`enum E: u8 { A = 300 }`).

`cast(u8, 300)` is still a C truncation. The check is the coercion,
not the cast.

Widths are the fixed integer widths. `int` is `i32`. `usize` / `isize`
use a 64-bit range, matching LP64 `size_t` / `ptrdiff_t` in host
emission. An operator on two untyped literals is still the `i32`
default, not a fold into the outer type: `let x: u8 = 200 + 100` is a
type mismatch (`i32` vs `u8`).

## D7. To decide later

- Closures — at all? Nelua does not have them outside top-level. A struct
  with environment + function pointer is medium difficulty, but allocating
  the environment breaks the overarching principle.
- Interfaces — fat pointer `{ void* data; Vtable* vt; }`. If so,
  dynamic dispatch is **explicit** in syntax (`dyn Writer`), static by default.
- Slice: `struct { T* ptr; size_t len, cap; }` — forces generics, so
  it depends on D3.
- Operators on user types — at all. Risk of hidden cost.
