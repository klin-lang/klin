# 072 — Enums (C23 style, optional underlying type)

**Status:** ✅ done (MVP: core + methods + explicit conversion; no string/kv-enum)
**Depends on:** 002 (checker/types), 005 (methods with receiver), 014 (`match`)
**User page:** [docs/syntax.md](../docs/syntax.md)

## Done (MVP)

- `enum E { … }` (underlying `i32`) and `enum E: T { … }` (integer underlying type,
  explicit values `= N`) — lexer/parser/checker/emission/fmt.
- Enum is a separate type; `==`/`!=` only within same enum (no ordering);
  use in `match` (patterns `Enum.Variant`, no ranges).
- Methods with receiver on enum (`fn (c: Color) name(): str`).
- Explicit enum↔number conversion via `cast` (no hidden coercion).
- Portable emission: `typedef <base>;` + anonymous `enum { … }` with constants
  (no C23 `enum E : T`, so gcc/clang/tcc), with `#line`.

Example: `examples/enums.kl`. Goldens: `test/enum_basic.kl`.

**Beyond this MVP** (still “under consideration”, sections below): string-enum, kv-enum,
bitflags (require [078](078-bitwise-ops.md)).
Enum as `[N]T` index → [126](126-enum-index.md) ✅.
Exhaustive `match` on enum → [129](129-enum-match-exhaustive.md) ✅.

## Goal

Add C23-style enums to Klin: a named set of constants, **optionally with
underlying type**. Enum should disappear in emission (plain `enum`/`int` in C) — zero
hidden cost (overarching principle). Today Klin has no enums (`enum` is not a
keyword).

## Core (MVP)

```klin
enum Color { Red, Green, Blue }         // default underlying type (int)
enum Status: u8 { Ok, Warn = 5, Err }   // optional underlying type + explicit values
```

- Values default to 0,1,2… (like C); explicit `= N` allowed.
- Optional underlying type: `enum E: u8 { … }` (C23 `enum E : uint8_t`).
- Enum is a **separate type** in checker (not `i32` alias); `==` comparisons,
  use in `match` ([014](014-match.md)).
- Conversion to/from number: explicit (e.g. `cast`/dedicated function) — no hidden
  coercion.

### Emission / portability (decide at implementation)

C23 “fixed underlying type" (`enum E : uint8_t`) supported by gcc 13+/clang 16+ with
`-std=c23`, but **tcc does not**. Default backend is gcc, but `--cc tcc` must
work. Options:
- underlying type given → emit portably: `typedef uint8_t E;` + `#define`/`enum`
  constants (or `static const`), instead of relying on C23; or
- emit C23 `enum E : T` only when backend supports it (flag), with fallback.
Resolve so `#line` and “gcc never errors" remain satisfied.

## Extension methods on enums — yes, worthwhile

Klin already has methods with receiver on structs (`fn (v: Vec2) len_sq()`). Same
mechanism fits enums (emission = plain C function taking enum value
— zero cost):

```klin
enum Color { Red, Green, Blue }

fn (c: Color) name(): str {
    match c {
        Color.Red { return "red" }
        Color.Green { return "green" }
        else { return "blue" }
    }
}
```

Recommendation: allow receiver on enum type (like struct). Closest to
**Go** model (named type + methods) and zero cost.

### How other languages do it (methods on enums)

| Language | Methods on enum |
|---|---|
| Go | enum = named int type (`iota`) + methods on that type — yes |
| Rust | `impl Enum { fn … }` — yes (algebraic enum) |
| Swift | methods / computed props / protocols — yes |
| Kotlin | `enum class` with methods (and abstract per variant) — yes |
| Java | enum = class with methods — yes |
| C# | enum = int without methods, but **extension methods** via `static` class — yes |
| Dart | **enhanced enums** (2.17+): fields/methods/constructors/interfaces; plus `extension on Enum` — yes |
| TS | enum without methods; workarounds via namespace/object |
| C / C23 | integer constants, **no** methods |

Conclusion: methods on enums are the norm (except C/TS). For Klin cheapest and consistent
model is “named type + receiver" (Go-like), without data-carrying variants (see below).

## Under consideration: string enums (TS style)

TS: `enum E { A = "a", B = "b" }`. In a language compiled to C a “string enum" is
not an enum (no integer discriminant), only a **named set of
`str` constants** (`const char*`). Convenient sometimes (e.g. names in logs/protocol), but:
- different feature than integer enum — confusing under one syntax;
- achievable as plain `pub` constants / `name()` function (above), so maybe
  not worth a separate “string enum".

Proposal: **skip for now**; if needed, use `fn (c: E) label(): str`
instead of string enum. Recorded as option, not commitment.

## Under consideration: KV-based enum / universal “kvenum" / string-enum

Separate, optional enum variant as a **key→value map** (not only
integer discriminant). Variants to consider:

- **kv-enum** — variant `variant = value` with one shared value type,
  e.g. `str` (string-enum), `i64`, or other scalar: `enum Http: str { Ok = "ok",
  NotFound = "not_found" }`. Emission: constant array (`static const`) indexed by
  discriminant + `value()` accessor — zero hidden cost.
- **universal kvenum** — each variant carries tuple/record metadata
  (e.g. `{ code: i32, label: str }`), like Dart “enhanced enum", but
  **without** heap and reflection: static record table + accessors. Already close to
  data-carrying variants, so boundary with “algebraic enum" (out of scope) must be
  clear: here **static** per-variant table, not runtime payload.
- **string-enum** (TS style) — special case of kv-enum with `str` value
  (see section above).

Relation to [060](060-map-kv.md): the hash map is ❌ struck (hidden
resize). Kvenum is the static, closed table — constant array, not a
map. Implementation via `$fn` if we do it at all.

Status: **under consideration** — as syntax extension of `enum` (per-variant values),
or as separate construct; and whether at all, since `fn (c: E)
value(): T` + `match` already covers it without a new feature.

## Out of scope (initially)

- Algebraic enums with data (Rust/Swift `enum` with payload) — large, separate
  topic (requires tagged union in emission); here only “C-like" enum.
- Automatic `to_string`/reflection without explicit method.
- Exhaustive `match` on enum — [129](129-enum-match-exhaustive.md) ✅.
- Bitflags/`enum` as flags (`|`/`&`) — possibly later; requires bitwise
  operators ([078](078-bitwise-ops.md)), which the language lacks today.

## Criteria (when work starts)

- [x] `enum E { … }` and `enum E: T { … }` (explicit values) — parser + checker.
- [x] Enum as separate type; use in `match`; explicit conversion to number.
- [x] Methods with receiver on enum (like struct) + golden.
- [x] Portable emission (gcc/clang/tcc), `#line`, “gcc does not error".
- [x] Decision: string-enum (TS) — skipped in MVP (see sections above).
