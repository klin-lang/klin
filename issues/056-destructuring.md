# 056 — Destructuring (`{}` / `[]` / multi-assign)

**Status:** ✅ — phases A (structs) + A′ (bare `{}=`) + B (multi-assign) + C (arrays `[N]T`) + D (rename / `_`). Bare `[]=` deliberately skipped (see below).
**Depends on:** [005](005-structs-methods.md) (struct lit/fields ✅); nice to have [007](007-pointers-arrays-slices.md) (fixed-length arrays)
**User page:** [docs/syntax.md](../docs/syntax.md)

> **Do not confuse with RAII destructors.** D6 ([docs/01-decisions.md](../docs/01-decisions.md)):
> no constructors/destructors. Here we mean **destructuring** —
> unpacking a value into multiple names in one statement.

## Motivation

Patterns like:

```
[a, b] = [b, a]     // swap / array unpack
[x] = tab           // first element?
{ x, y } = p        // struct fields
a, b = b, a         // multi-assign like Go/V (no parentheses)
```

Today Klin has `[…]` / `Typ{ … }` literals and single `target = expr`.
No unpacking and no simultaneous assignment to multiple LHS.

## Go / V — do they have tuples?

| Language | Tuple as first-class type? | Instead |
|---|---|---|
| **Go** | **No.** Deliberate decision. | Multi-arg `return`; multi-assign `a, b = b, a`; “tuple” = struct or separate values. |
| **V** | **No** (no `tuple` type in docs). | Multi-assign / swap `a, b = b, a`; multi-return; compound data = **struct**. Array/`{}` destructuring — community proposals, not core. |

**Conclusion for Klin:** do not add tuples. We have structs, `!T`, fixed-length
arrays — that is enough. Tuples are a second way to do the same as an
anonymous struct, with worse messages and collision with literals.

## Direction (preferred)

### 1. Struct `{}` — natural MVP

Since we have structs and named/positional literals, destructuring by
**field names** is simple and vanishes in emission (plain `.field`):

```
let p = Vec2{ x: 3, y: 4 }
let { x, y } = p          // ≡ let x = p.x; let y = p.y
let mut { x, y } = p      // mutable locals
{ x, y } = p              // assign to existing (requires mut)
```

- order in `{}` irrelevant (like named literal)
- field subset OK; missing fields = not introduced
- rename later: `{ x: px, y: py }` (optional, not in phase 1)
- `_` to skip? probably unnecessary with subset

Overarching rule: emission = sequence of field reads / local writes.
Zero allocation, zero hidden copying beyond what `let`
of a struct already does (value copy as today).

### 2. Multi-assign (Go/V) — swap without array

```
a, b = b, a
x, y = foo()          // only when/if multi-return
```

- RHS evaluated “in parallel” (tmp like Go) — visible in emitted C
- does not require a new type
- covers swap without `[a,b]=[b,a]`

### 3. Arrays `[…]` — fixed length only

```
let xs: [2]i32 = [10, 20]
let [a, b] = xs           // ≡ let a = xs[0]; let b = xs[1]
[a, b] = [b, a]           // swap via literal / pattern
```

- **only** `[N]T` with known `N` at compile time
- **not** slice `[]T` (runtime length → exception / panic — breaks
  “frontend catches errors” or requires hidden check)
- pattern count == `N` (or `N` with `_` — decision later)

`[x] = tab` with `tab: [3]i32` is **ambiguous** (first?
whole thing?). Proposal: either forbid (require full coverage), or
explicit index / slice — not `[x]=` sugar.

## Out of scope (initially)

- `tuple` type / `(T, U)` in grammar
- destructuring slice / dynamic collections
- pattern matching in `if` / `match` (separate topic, if ever)
- destructors / RAII (D6 stays)
- multi-return functions (maybe later; today `!T` + struct is enough)

## Phases (when implementation opens)

| Phase | What | Depends | Status |
|---|---|---|---|
| A | `let { a, b } = s` (declaration) | 005 | ✅ |
| A′ | bare `{ a, b } = s` (reassign; needs lookahead) | 005 | ✅ (struct); `[]=` skipped |
| B | `a, b = b, a` (multi-assign, no multi-return) | parser + checker tmp | ✅ |
| C | `let [a, b] = xs` for `[N]T`, known `N` | 007 | ✅ |
| D | rename `{ x: px }`, `_` in arrays (skip) | after A/C | ✅ |

**Phase A (done):** `let { … } = expr` and `let mut { … } = expr` for structs —
field subset, order irrelevant, source evaluated once (copy to temporary when
not a name), lowered to `.field`. Example
[`examples/destructure.kl`](../examples/destructure.kl), tests in
[`test/destruct_struct.kl`](../test/destruct_struct.kl) +
`test/pipeline_test.dart`.

**Phase C (done):** `let [a, b] = xs` and `let mut [a, b] = xs` for fixed-length
arrays `[N]T`, where `N` == pattern count (full coverage, no
`[x] = tab` ambiguity). Named array indexed in place
(`xs[i]`), array literal bound element by element. Rejected by
frontend: slice `[]T` (runtime length), length mismatch, source other than
variable/array literal, nested array element. Example
[`examples/destructure.kl`](../examples/destructure.kl), tests
in [`test/destruct_array.kl`](../test/destruct_array.kl) +
`test/pipeline_test.dart`.

**Phase B (done):** multi-assign `a, b = b, a` — ≥2 assignable targets and as many
values. Values computed into temporaries before any write, so
swap/rotation work without a temporary in the source. Targets follow normal
lvalue/`mut` rules; rejected: whole-array target and values with `or`/`!`/`match`
(assign them in a separate statement). Example
[`examples/multi_assign.kl`](../examples/multi_assign.kl), tests in
[`test/multi_assign.kl`](../test/multi_assign.kl) + `test/pipeline_test.dart`.

**Phase D (done):** struct field rename `let { x: px, y: py } = p` (mixable
with unchanged field names) and `_` as skip position in array
`let [_, b, _, d] = xs` (full coverage still required, min. one real
binding; indices preserved). Tests in
[`test/destruct_phase_d.kl`](../test/destruct_phase_d.kl) +
`test/pipeline_test.dart`.

**Phase A′ (done — structs):** bare `{ x, y } = p` and rename `{ x: cel } = p`
assign fields to existing places (variables or any lvalue). Block vs
pattern distinguished by limited lookahead (`=` after matched `}`); source
copied once, so target can safely alias source. Example
[`examples/destructure.kl`](../examples/destructure.kl), tests in
[`test/struct_assign.kl`](../test/struct_assign.kl) + `test/pipeline_test.dart`.

**Bare `[ … ] = xs` — deliberately skipped:** with whitespace-insensitive
grammar, a statement starting with `[` glues to the previous expression as
postfix index (`prev[…]`). Substitute: phase B multi-assign
(`a, b = xs[0], xs[1]`, swap `a, b = b, a`).

## “Issue closed as decision” criteria

- [x] confirmation: **no tuples**
- [x] choice of phase A as first (struct `{}`)
- [x] decision: multi-assign B **after** arrays is OK; B/C order open,
  but phase A (struct) goes first and is already implemented
- [x] for arrays (phase C): explicit `_`, **not** JS-style holes `[,,a,b]`
  (Go/V consistency, readability; zero-cost identical, so ergonomics decides)
