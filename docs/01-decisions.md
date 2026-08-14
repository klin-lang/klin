# Design decisions

This is the decision log (D1–D9), not an introduction. Start with
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

---

## D3. Generics — DECIDED

**Choice: preprocessor/compile-time macros, NOT in the language grammar.**

Nelua model: a powerful preprocessor with AST access generates
specialized code. Classes, generics, and polymorphism implemented
ad hoc, without putting them in the core.

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

## D7. To decide later

- Closures — at all? Nelua does not have them outside top-level. A struct
  with environment + function pointer is medium difficulty, but allocating
  the environment breaks the overarching principle.
- Interfaces — fat pointer `{ void* data; Vtable* vt; }`. If so,
  dynamic dispatch is **explicit** in syntax (`dyn Writer`), static by default.
- Slice: `struct { T* ptr; size_t len, cap; }` — forces generics, so
  it depends on D3.
- Operators on user types — at all. Risk of hidden cost.
