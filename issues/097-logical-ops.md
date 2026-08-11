# 097 — Logical operators (`&&` / `||`)

**Status:** ✅ done (MVP)  
**Depends on:** [002](002-symbol-table-checker.md) (bool / checker), [003](003-control-flow.md); related [078](078-bitwise-ops.md), [085](085-pick.md)

## Goal

Add short-circuit logical AND / OR in Klin source. Previously only bitwise
`&` / `|` existed; `a && b` lexed as two `&` tokens and parsed as
`a & (&b)` (address-of trap).

## Scope (MVP) — done

| Klin | Meaning | C |
|---|---|---|
| `a && b` | short-circuit AND | `a && b` |
| `a \|\| b` | short-circuit OR | `a \|\| b` |
| `!a` | logical NOT (already) | `!(a)` |

Semantic rules:
- Both operands **`bool` only**; result `bool` (same as `if` conditions —
  no numeric truthiness).
- Short-circuit via C emission (no Klin runtime helper).
- Keyword `or` remains error-handling (`or { … }` — D2); no `and` / `or`
  logical aliases.
- Conditional values: [`pick`](085-pick.md) (not `? :`).

## Precedence (settled — D9)

```
error-or { }  →  ||  →  &&  →  == !=  →  comparisons  →  |  →  ^  →  &  →  …
```

Like Rust’s logical tier above equality; bitwise stays Rust-like (D8).

## Implementation points

- `lib/token.dart` + `lib/lexer.dart`: `ampAmp` / `pipePipe`
- `lib/parser.dart`: `_logicalOr` / `_logicalAnd` between error-`or` and equality
- `lib/checker.dart`: `_logicalOps` / `_inferLogical`
- Emission / `fmt`: existing `BinaryExpr` 1:1
- TextMate: `&&` / `||` before single `&` / `|`

## Criteria

- [x] Tokens + parser (D9 precedence); `&&` is not `a & (&b)`
- [x] Checker: `bool` only; clear error on `i32 && …`
- [x] Golden + short-circuit side-effect test; `fmt` idempotent
- [x] Docs: D9, README, example [`examples/logical.kl`](../examples/logical.kl)

## Out of scope

- Soft truthiness (`if 1`)
- `and` / `or` keyword aliases
- `? :` ternary — use `pick`

## Related

- [078](078-bitwise-ops.md) — bitwise `&` / `|` (integers)
- [085](085-pick.md) — conditional expression (`pick`)
- Board pack `nucleo_f411re` `button_b1` uses `&&` after this lands
