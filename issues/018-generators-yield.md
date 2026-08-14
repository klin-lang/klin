# 018 — Generators / `yield`

**Status:** ❌ not doing — no JS-style `yield` in the core
([125](125-drop-host-json-sqlite.md))
**Depends on:** 004 (functions), possibly closures / state (D7); not on main queue

`async` / `.await` already desugar to a state machine ([029](029-async-event-loop.md)).
A second suspend keyword is hidden control flow. An iterator is a
struct with `next()` — write it; do not add `yield`.

## Context

JS/`async`/`function*`: `yield` suspends a function and yields a value to an iterator. Convenient for streams and lazy sequences, but requires **hidden state** (stack frame on heap or transformation to state machine) — strongly at odds with Klin's prime rule.

## Proposal (later, if at all)

- Either **do not** introduce `yield` in the core.
- Or explicit model: generator = struct with state + `next(): ?T` method (like iterators in V/Zig/Rust), without magical stack suspension.
- Emission to C: state machine generated explicitly (visible in `.c`) or manual iterators — zero hidden frame allocation without `Allocator`.

## What not to do

- Do not promise `yield` like Python/JS before deciding on cost and allocation.
- Do not add before solid functions (004) and slices/iterators (007).
- Prime rule test: generator vs manual C loop — same machine code or the feature drops out.

`yield` is unrelated to the SVD generator from [011](011-svd.md): that one is a
build-time tool, without hidden user-program state.
