# 026 — Preprocessor (`$…`, D3)

**Status:** ✅ done
**Depends on:** stable frontend (practically after 010+)

## Goal

Implementation of decision D3 ([docs/01-decisions.md](../docs/01-decisions.md)):
compile-time macros. This **is** Klin’s generic — `$fn` expands to
plain `fn` before parse. Not `[T]` in the checker. User page:
[docs/04-macros.md](../docs/04-macros.md). Grammar sugar → [034](034-generic-types.md).

## MVP

- `$fn name(param: type|name|str, …) { … }` — definition (body as text with
  `$param` slots)
- `$name(args…)` — call; expand **before** lex/parse/check/emit
- `--emit-pp` → `out/<file>.pp.kl` (expansion preview)
- preprocessor errors with call position (`unknown macro`, wrong arity, …)

Example (as in D3, simplified `name` instead of string literal):

```
$fn point(name: name, T: type) {
  struct $name { x: $T  y: $T }
  fn (p: $name) len_sq(): $T { return p.x * p.x + p.y * p.y }
}
$point(Vec2i, i32)
```

## Outside MVP

- full template language / AST-quote like Nelua
- `$peripherals_from_svd` → [027](027-svd-ergonomic-api.md)
- mapping checker positions back to macro body
- macros from package + `$kstruct` / `$kstruct_from` → [059](059-kstruct-macros.md)


## Criteria

- [x] simple macro generates specialized AST (golden `point_macro.kl`)
- [x] `--emit-pp` writes expanded source
