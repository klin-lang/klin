# 119 — Guide: `if` / `defer` / `import` + precedence

**Status:** ✅ done
**Depends on:** [116](116-docs-reorg.md), [003](003-control-flow.md),
[008](008-defer.md), [006](006-modules.md)

## Problem

The short tutorial ([docs/guide.md](../docs/guide.md), issue 116) jumped
from structs to `!T` and skipped the everyday surface: `if` / loops,
`defer`, `module` / `import` / `pub`, and operator order. Those lived
only in issues and D8 / D9. A new reader could write `hello` and a
method, then guess C precedence (`a & b == c`) or miss that `or` is
error-handling.

## Done

- [x] [docs/guide.md](../docs/guide.md) — §4 control flow, §6 `defer`,
  §8 modules / `import`, §9 precedence (tightest → loosest; Rust-like
  bitwise; `or { }` loosest)
- [x] Map / landing / D8–D9 point at the new sections
- [x] Runnable pointers stay in `examples/` and `test/fizzbuzz.kl`

## Out of scope

- Full language spec / grammar
- Dedicated notes for enums / associated fns / destructuring
- New language features
