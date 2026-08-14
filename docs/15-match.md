# `match` — pattern matching with default break

Issue: [014](../issues/014-match.md) (MVP), [084](../issues/084-match-when-rel.md)
(`when` guards + relational patterns),
[129](../issues/129-enum-match-exhaustive.md) (exhaustive enum `match`),
[132](../issues/132-match-else-or.md) (`else { error(n) }` + `or`).

## Syntax

Statement:

```
match x {
    1, 2, 3 {
        puts("small")
    }
    4..=10 {
        puts("mid")
    }
    > 0 when ready != 0 {
        puts("ready-pos")
    }
    _ when special {
        puts("guarded catch")
    }
    else {
        puts("big")
    }
}
```

Expression (only as `let` initializer or right-hand side of assignment):

```
let fee = match x {
    0      { 0 }
    1..=5  { 10 }
    >= 10 when ready != 0 { 40 }
    else   { 25 }
}
```

Arm patterns:

- value group: `1, 2, 3`
- **closed on both ends** range: `4..=10` (separate token `..=`;
  `..<` remains half-open range for `for`)
- relational: `> e`, `>= e`, `< e`, `<= e`, `!= e` (no `==` — use a
  value group)
- wildcard `_` — always matches the subject; **requires** a `when` guard
  (use `else` for an unguarded catch-all)
- `else` — must be last; cannot have `when`

Optional guard on any non-`else` arm:

```
pattern when <bool expr> { … }
```

## Semantics

- **Default break.** The first matching arm runs; no fallthrough
  and no `fallthrough` keyword.
- An arm matches when its pattern matches the subject **and** its `when`
  guard (if any) is true.
- Subject must be **integral** (`i8`…`u64`, `int`) or an **enum**. `f64`,
  struct, pointer → checker error.
- Relational and range patterns are **not** allowed on enum subjects
  (only value groups + `when` + `else`).
- **Enum subjects are exhaustive.** Every variant must appear in an
  unguarded value group, or the last arm must be `else`. A `when` guard
  does not cover that variant (the guard can fail). A runtime value
  (`other` of the same enum) does not cover a name. Integers stay open:
  statement `else` is optional (no match does nothing); expression
  `else` is still required.
- `else` on an enum is the hatch for a leftover discriminant after
  `cast` (`cast(Color, 99)`).
- An arm is a block, not `case`: `break` / `continue` in an arm refer to the
  enclosing loop, `return` returns from the function (and runs `defer`).
- Expression type: common type of arms (unification like array literals);
  `match` counts as returning on all paths when every arm returns and
  the arms cover the subject (`else`, or every enum variant).
- **`error(n)` in an arm** makes the expression `!T` (ok type from the
  success arms). A root `or { … }` may unwrap it:

```
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

  A named `fn …(): !T` with `return error(n)` stays valid — both forms
  ([132](../issues/132-match-else-or.md)).

## Emission

Chain of `if` / `else if` / `else`. Subject lands **once** in a temporary
variable, so multi-value patterns and ranges do not re-evaluate it.
A `when` guard is AND-ed into the same condition (`_ when g` emits only
`(g)`):

```c
int32_t klin_val_0 = x;
if (klin_val_0 == 1 || klin_val_0 == 2 || klin_val_0 == 3) {
    puts("small");
} else if ((klin_val_0 >= 4 && klin_val_0 <= 10)) {
    puts("mid");
} else if (((klin_val_0 > 0) && (ready != 0))) {
    puts("ready-pos");
} else if ((special)) {
    puts("guarded catch");
} else {
    puts("big");
}
```

Expression form lowers to target declaration + assignment in branches
(hence allowed only in `let` / assignment position):

```c
int32_t fee;
int32_t klin_val_0 = x;
if (klin_val_0 == 0) { fee = 0; } else if (…) { fee = 10; } else { fee = 25; }
```

Deliberately **not** `switch`: `switch` does not handle ranges portably
(`case 4 ... 10` is a GCC extension), and `break` in `case` would clash with
loop `break`. An `if` chain gives the same machine code as hand-written C —
overarching principle satisfied.

## Limitations

- no `|` as alternative — use `,`
- no matching on strings and structs (`str` is not yet a value
  type)
- no dead-arm warnings (a second `Color.Red` is still accepted)
- `match` as expression only in `let` / assignment; in call argument
  → checker error with hint
- subject in header does not accept bare struct literal
  (`match Point{…}.x` — use parentheses: `match (Point{…}).x`), because `{`
  opens the arm block

Example: [`examples/match.kl`](../examples/match.kl),
[`examples/enums.kl`](../examples/enums.kl).
Tests: `test/match_stmt.kl`, `test/match_expr.kl`, `test/match_when.kl`,
`test/match_rel.kl`, `test/fmt_match.kl`, `test/enum_match_exh.kl`,
`test/match_else_or.kl`.
