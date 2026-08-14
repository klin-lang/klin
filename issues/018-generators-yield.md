# 018 — ~~Generators / `yield`~~

**Status:** ❌ struck — no `yield` in the core, not “later”
([125](125-drop-host-json-sqlite.md))

`async` / `.await` already desugar to a state machine
([029](029-async-event-loop.md)). A second suspend keyword is hidden
control flow. An iterator is a struct with `next()` — write it.

Do not reopen as “small `yield`” or “just for streams.”

Unrelated to the SVD **generator** ([011](011-svd.md)) — that is a
build-time tool.

## Historical note (not a plan)

Was: JS/`function*` `yield`, or a compiler-built state machine for
iterators. Rejected. Manual `next()` on a struct is ordinary Klin,
not this issue.
