# 132 — `match { … else { error(n) } } or { … }`

**Status:** 💭 planned (before 1.0; not after the `.kl` freeze)
**Depends on:** [009](009-errors.md) (D2), [014](014-match.md)

Filed as 130; renumbered because `main` already has
[130-winget](130-winget-scoop-windows.md) /
[130-gd32v-ble](130-gd32v-ble-sdk.md).

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

Today `error(n)` is only legal in a function that returns `!T` (it
builds that function’s error return). `match` as an expression must be
the entire `let` / `=` RHS, so `match { } or { }` is rejected. Success
may be local (`let n = match …`); failure of the same thought must
leave to a `fn`.

The real change is D2, not a `match`-only hack:

1. `error(n)` is a `!T` **value** (ok-type from context: other arms or
   an annotation). Still `error(1)` — an `i32` code. No bare `error`.
2. `match` arms: all `T` → result `T`. Any `error(n)` / `!T` → result
   `!T` (success arms wrap like `return "red"` in `fn (): !str`).
3. `or` unwraps any `!T` expression, including such a `match`, when
   the `or` is the `let` / `=` root.

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

No new grammar. Parser already accepts `OrExpr(MatchExpr, …)` (`or`
binds loosest). Checker + emit.

Emission stays a tagged struct + `if (is_err)` — the same C you would
write in `main`. A helper that exists only so `error()` can return is
an extra C function the programmer did not ask for.

## Out of scope

- `else { error }` without a code
- Automatic `error(1)` on a leftover (`cast(Color, 4)`) when `else` is
  missing — hidden control flow
- `match` in call arguments / `pick` / arithmetic
- Algebraic `Ok` / `Err` patterns
- Changing integer `match` exhaustiveness

## When

Next language step after [129](129-enum-match-exhaustive.md), **before
1.0**. After the `.kl` freeze, `error(n)` would change meaning in a
stable language (or the function tax stays forever).

## Criteria (when work starts)

- [ ] `error(n)` as `!T` in expression position (incl. `main`)
- [ ] `match` unifies `T` + `error(n)` → `!T`
- [ ] `let x = match { … } or { … }` when the `match` is `!T`
- [ ] Existing `fn …(): !T` + `return error(n)` unchanged
- [ ] Golden + checker errors (`error` without a code, `T`/`!U` mismatch)
- [ ] Docs: D2, [15-match](../docs/15-match.md), guide §5
