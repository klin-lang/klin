# 120 — User page: enums / `Type.fn` / destructuring

**Status:** ✅ done
**Depends on:** [116](116-docs-reorg.md), [072](072-enums.md),
[079](079-associated-functions.md), [056](056-destructuring.md)

## Problem

After the docs map ([116](116-docs-reorg.md)) the tutorial
([guide.md](../docs/guide.md)) still skipped three everyday forms that
already compile: C-style enums, associated `Type.fn`, and destructuring
/ multi-assign. Readers were sent to `issues/` — which is the roadmap,
not a manual.

## Done

- [x] One page [docs/syntax.md](../docs/syntax.md) — “the rest of the
  syntax”, not three notes and not a spec
- [x] Map / guide / idea / examples point at it
- [x] 072 / 079 / 056 carry a user-page pointer
- [x] Runnable proof stays in `examples/enums.kl`,
  `associated_fn.kl`, `destructure.kl`, `multi_assign.kl`

## Out of scope

- Full language spec / grammar
- Expanding the guide into a feature dump
- New language features (string-enum, tuples, algebraic variants, …)
