# `pick` — two-way expression choice

Issue: [085](../issues/085-pick.md).

## Syntax

```
let fee = pick ready != 0 { 10 } { 0 }
fee = pick x > 10 { 40 } { 25 }
printf("%d\n", pick flag { 1 } { 0 })
```

Nested:

```
let kind = pick x < 0 {
    -1
} {
    pick x > 10 { 2 } { 1 }
}
```

## Semantics

- Condition must be `bool`.
- Then/else expressions share a common type (same unification as `match`
  expression arms / array elements). Untyped arms adopt the expected
  type and are range-checked (`let x: u8 = pick c { 1 + 2 } { 4 }`;
  `300` is the `u8` error). With no expected type they are `i32`
  ([D12](01-decisions.md)).
- `pick` is a normal expression: valid in `let` / `:=` / assignment, call
  arguments, nested inside another `pick`, etc.
- Statement `if` is unchanged — use `pick` when you need a value.

## Emission

Plain C ternary — zero hidden cost:

```c
int32_t fee = ((ready != 0) ? 10 : 0);
```

## Limitations

Arms cannot contain forms that lower to statements (`match`, `or`, `!`),
because those cannot appear inside a C `?:`. Use a statement `if` / `let` +
`match` for those cases.

Example: [`examples/pick.kl`](../examples/pick.kl).
Tests: `test/pick_expr.kl`, `test/fmt_pick.kl`.
