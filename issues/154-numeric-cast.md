# 154 — Numeric `cast` (integer ↔ integer, float ↔ float, int ↔ float)

**Status:** planned
**Depends on:** [002](002-symbol-table-checker.md) (checker/types), [019](019-default-int-types.md),
[072](072-enums.md) (`cast` surface already exists)

## Context

Today `cast(T, expr)` is an MVP with two families only
(`lib/checker.dart` — error *"MVP cast supports pointer or enum/integer
conversions"*):

| Allowed | Example | Emission |
|---|---|---|
| integer / pointer → pointer | `cast(*mut u32, addr)` | `(T*)(uintptr_t)(…)` |
| integer ↔ enum | `cast(Status, 5)`, `cast(i32, s)` | plain C cast |

**Missing:** any conversion between concrete numeric prims
(`i8`…`i64`, `u8`…`u64`, `usize`/`isize`, `f32`/`f64`, aliases `int`/`float`).

Assignment and operators stay strict: `_isAssignable` / `_unifyNumeric`
require the **same** concrete prim (plus untyped literal coercion). So
`let x: i32 = …` cannot become `i64` / `f64` without a cast — and the
cast is rejected. Mixed-width and FFI code has no honest path.

Literal coercion is unchanged and stays the *only* implicit numeric
path (untyped int → integer or float context; untyped float → `f32`/`f64`).
That is by design ([081](081-number-literals.md)); this issue does **not**
add C-style promotions or silent widen on assign.

## Goal

Extend the existing `cast` form so numeric prim ↔ numeric prim is
explicit, zero-cost, and disappears as a C cast — same overarching
rule as the rest of Klin.

```klin
let a: i32 = 40
let b: i64 = cast(i64, a)
let c: f64 = cast(f64, a)
let d: u8 = cast(u8, b)
let e: f32 = cast(f32, c)
```

No new keyword. No `@intCast` / `@floatCast` split (Zig). No `as`
suffix. One verb: `cast(T, expr)`.

## Design (settled for MVP)

### Allowed targets / sources

- **Source** after materializing untyped literals: `PrimType` with
  `isInteger` or `isFloat`.
- **Target:** same — any integer or float prim (including `int`→`i32`,
  `float`→`f64` via existing `PrimKind.tryParse`).
- **Same type** `cast(i32, x)` where `x: i32` — allowed (no-op in C);
  useful for macros / generated code.
- **Enum ↔ integer** — keep current rules ([072](072-enums.md)); do not
  route float ↔ enum through this issue.
- **Pointers** — unchanged (still via `uintptr_t`).

### Rejected in MVP

| Case | Reason |
|---|---|
| `bool` as source or target | No numeric truthiness elsewhere; keep `bool` closed. Use `if` / `pick`, not cast. |
| struct / array / slice / `str` / `fn` / `!T` | Not numeric. |
| float ↔ enum | Enum underlying type is integer only. |
| Implicit widen/narrow on assign or in `+`/`*` | Hidden cost / C footgun. Still require `cast`. |

### Semantics = C cast (documented)

Emission for numeric casts is already the non-pointer arm in
`lib/emit/expr.dart`: `(T)(expr)`. Frontend rules must match that:

- Integer → narrower integer: truncation / wrap like C.
- Signed ↔ unsigned: reinterpret per C cast (implementation-defined
  edge cases stay C’s; Klin does not invent saturating casts).
- Float → float: usual C conversion (`float`/`double`).
- Integer → float / float → integer: C conversion (toward-zero for
  float→int in ISO C when the value fits; out-of-range is UB in C —
  no Klin runtime check in MVP).
- `usize` / `isize`: emit as today (`size_t` / `ptrdiff_t`).

No saturating / checked casts in the language. If needed later, they
are stdlib / `@[cimport]`, not new syntax.

### Untyped literals inside `cast`

`cast(i64, 1)` / `cast(f32, 1.0)`: materialize the literal to a
compatible untyped→prim path (int literal → integer or float target;
float literal → float target only). Reject `cast(i32, 1.5)` (float
literal to integer) unless we decide otherwise — **MVP: reject** float
literal → integer target (write `cast(i32, cast(f64, 1.5))` or use an
integer literal). Keeps the “no surprise truncate of `1.5`” story.

## Implementation plan

1. **Checker** (`lib/checker.dart`, `CastExpr` arm):
   - After pointer and enum arms, add: if `target is PrimType` and
     numeric, resolve `source` via `_defaultConcrete` / existing
     untyped rules; if source prim is numeric, `_materialize` and
     return `target`.
   - Else keep a clearer error (drop the “MVP” wording), e.g.
     `cast supports pointer, enum↔integer, or numeric conversions`.
2. **Emit / async emit** — no change expected for numeric (already
   `(T)(expr)`). Re-check `lib/emit/async.dart` mirror.
3. **Fmt / AST / complete** — `cast` already known; no syntax change.
4. **Docs:**
   - [docs/syntax.md](../docs/syntax.md) — short “Numeric cast” note
     (or extend the enum conversion bullet into a cast section).
   - [docs/guide.md](../docs/guide.md) — one example next to integers/floats.
   - Optionally mention under “In the language” only if cast becomes
     worth listing on [docs/language.md](../docs/language.md) (cast
     already exists; numeric is filling the MVP hole — a footnote is
     enough).
5. **Tests / example:**
   - Golden `test/numeric_cast.kl` (or extend an existing numeric
     golden): widen, narrow, signed↔unsigned, int↔float, `int`/`float`
     aliases, same-type no-op.
   - Negative checker tests: `bool`, struct, float↔enum, float lit →
     int target.
   - Small `examples/numeric_cast.kl` if useful for the catalog.
6. **`sorted.md`** — mark ✅ when done.

## Relation to other issues

- Completes the hole left by [072](072-enums.md) (`cast` introduced for
  enum↔int) and the explicit “MVP” checker message.
- Complements [019](019-default-int-types.md) / [081](081-number-literals.md):
  fixed-size types + untyped literals; concrete↔concrete stays explicit.
- Unblocks honest use of [083](083-stdlib-math.md) with mixed widths
  (e.g. `i64` path that must not go through float by accident).
- Does **not** reopen literal suffixes (`123i64`) — still out of
  [081](081-number-literals.md).

## Out of scope

- Implicit numeric promotions (C / Java style).
- Saturating / checked / wrapping-named casts as syntax.
- `bool` ↔ integer.
- Bitcast / transmute of unrelated sizes (use pointers + `cast` if
  needed; not a sugar).
- Changing `_unifyNumeric` to auto-widen in operators.

## Completion criteria

- [ ] Checker accepts numeric prim ↔ numeric prim via `cast(T, expr)`.
- [ ] Checker still rejects `bool` / non-numeric / float↔enum.
- [ ] Emission remains a plain C cast (pointers still via `uintptr_t`).
- [ ] Untyped int/float inside `cast` follow the rules above.
- [ ] Docs (syntax and/or guide) describe semantics = C.
- [ ] Golden + negative tests; `dart analyze` / `dart test` green.
- [ ] Entry in [sorted.md](sorted.md) marked ✅.
