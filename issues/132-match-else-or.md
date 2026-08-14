# 132 — `match { … else { error(n) } } or { … }`

**Status:** ✅ done
**Depends on:** [009](009-errors.md) (D2), [014](014-match.md)

Filed as 130; renumbered to 132 because `main` already had
[130](130-winget-scoop-windows.md) (WinGet/Scoop). GD32V BLE is now
[140](140-gd32v-ble-sdk.md).

## Verdict

Worth doing. Both forms stay available:

- `fn …(): !T` + `return error(n)` — named map, reuse, contract
- `let x = match { … else { error(n) } } or { … }` — local, one-shot

Do not force a helper function for a one-off `match`. Wrapping every
line and jumping the call stack is not a virtue. A function exists when
the unit has a reason (reuse, test, name, ABI).

Not enum-specific. The leftover after `cast(Color, 4)` is just one
place you write `else { error(1) }`. Same shape for an integer `match`.

## What

`error(n)` is a `!T` **value** (D2), not only a `return` from
`fn …(): !T`:

1. In a function returning `!T`, `error(n)` still builds that return type.
2. In a `match` expression, success arms supply the ok type; any
   `error(n)` / `!T` arm makes the result `!T`.
3. A root `or { … }` unwraps such a `match` (`let` / `=` only — same
   rule as bare `match`).

```klin
let s = match c {
    Color.Red { "red" }
    Color.Green { "green" }
    Color.Blue { "blue" }
    else { error(1) }
} or {
    printf("bad: %d\n", err)
    "??"
}
```

The function form stays:

```klin
fn color_name(c: Color): !str {
    match c {
        Color.Red { return "red" }
        else { return error(1) }
    }
}
let s = color_name(c) or { "??" }
```

No new grammar. Parser already accepted `OrExpr(MatchExpr, …)`.
Emission stays a tagged struct + `if (is_err)`.

## Done

- [x] `error(n)` as `!T` in expression position (incl. `main` via `match`
  / annotated `let x: !T = error(n)`)
- [x] `match` unifies `T` + `error(n)` → `!T`
- [x] `let x = match { … } or { … }` when the `match` is `!T`
- [x] Existing `fn …(): !T` + `return error(n)` unchanged
- [x] Golden [`test/match_else_or.kl`](../test/match_else_or.kl) + checker
  errors
- [x] Docs: D2, [15-match](../docs/15-match.md), guide §5, [language](../docs/language.md)

## Out of scope

- `else { error }` without a code
- Automatic `error(1)` on a leftover (`cast(Color, 4)`) when `else` is
  missing — hidden control flow
- `match` in call arguments / `pick` / arithmetic
- Algebraic `Ok` / `Err` patterns
- Changing integer `match` exhaustiveness
