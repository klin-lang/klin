# 077 — String substitution / runtime templates (`format` / `template`)

**Status:** 💭 under consideration (low priority — non-blocking)
**Depends on:** [007](007-pointers-arrays-slices.md) (slice/buffers), [057](057-allocator.md) (heap explicit); contrast [016](016-string-interpolation.md); placement/API like [017](017-collection-methods.md), [012](012-stdlib-io.md). KV map ([060](060-map-kv.md)) is ❌ struck (hidden resize) — templates stay a linear pair list.

## Idea (from discussion)

I want a lib or part of Klin that **substitutes braces** in a string **at runtime**:

- **positional**: `"{0}, {1}"`, `arg1`, `arg2`
- **dictionary (KV)**: `"{aaa}, {bbb}"`, kv_list

Template-as-**data** (string may be variable / from file / from config),
not known at compile time.

## Difference from 016 (not the same)

[016](016-string-interpolation.md) = **compile-time interpolation**: `"$name"`,
`"${expr}"`, `"${x:0.00}"`. Braces and expressions are known to compiler → emission is
`printf` (zero allocation, zero runtime). Here the opposite: **pattern is a value**,
so substitution happens at runtime (scan string, match key).
Both are valid and complement each other.

## Overarching principle (shapes API)

No hidden allocation / control / cost. Therefore **not** `str format(...)`
with magic heap, only:

- **layer 1 (zero-alloc)** — write to caller-provided buffer:
  `fn render(tmpl: str, ..., out: []u8): !i32` (returns bytes written;
  `!` = overflow/bad pattern),
- **layer 2 (heap explicit)** — via `Allocator` ([057](057-allocator.md)), like
  `slice_alloc`: `fn render_alloc(a: Allocator, tmpl: str, ...): !str` + `defer`
  at caller.

## Variants

### A. Positional `{0} {1} …`

- Arguments as `[]str` (MVP: strings only — no generics in grammar, D3).
- Non-`str` types formatted first (`time.fmt`,
  016 interpolation) → get `str` and put in list.
- `{0}` may appear many times; index out of range → error (`!`).

### B. Dictionary `{key}`

- KV pair list: `[]KV` where `struct KV { key: str; val: str }` (simple,
  linear search). Hash map ([060](060-map-kv.md)) is ❌ struck.
- Key not found → decision: error (`!`) or empty/“leave braces”
  (TBD; MVP: error).

## To decide

- **Escaping**: `{{` / `}}` → literal `{` / `}` (like .NET/Rust `format!`).
- **No match**: error vs leaving `{x}` in output.
- **One scan or two** (count size first, then write) for layer 2.
- **Only `str`** in MVP (typed values → earlier via 016/`time`), or
  later typed variants via `$fn` (`render_i32`, …).
- **Name/module**: `stdlib/strfmt`? `stdlib/template`? part of `str`/`io`?

## Sketch (later — not now)

```
struct KV { key: str; val: str }

# positional, zero-alloc: "{0}, {1}" + [arg0, arg1] -> out
fn render_pos(tmpl: str, args: []str, out: []u8): !i32 { /* scan {N} */ }

# dictionary, zero-alloc: "{aaa}, {bbb}" + [KV{...}, ...] -> out
fn render_kv(tmpl: str, kvs: []KV, out: []u8): !i32 { /* scan {key} */ }

# layer 2 (heap explicit)
fn render_pos_alloc(a: Allocator, tmpl: str, args: []str): !str { /* + defer */ }
```

## Out of scope

- implementation in this issue (roadmap placeholder),
- full KV map / hash ([060](060-map-kv.md) ❌ hidden resize) — linear pair list only,
- mixed typed arguments (`{0:%.2f}`) as MVP requirement — strings first,
- format specifiers in braces (`{0:...}`) — rather 016 extension,
- localization / pluralization / ICU MessageFormat.
