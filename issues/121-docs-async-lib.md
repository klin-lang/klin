# 121 — Map: event loop is a library; `async` / `.await` are language

**Status:** ✅ done
**Depends on:** [116](116-docs-reorg.md), [029](029-async-event-loop.md)

## Problem

After the docs map ([116](116-docs-reorg.md)) a reader could treat Klin
as having a Node-style async **runtime**. The first map sentence then
over-corrected: “async = library, not the language.” That is false for
the keywords. [029](029-async-event-loop.md) already splits the two:

1. **Loop / executor** — library (`eventloop`). No hidden scheduler.
2. **`async fn` / `.await`** — **core** (parser + emit → state machine).
   A `.kl` file cannot add real `await`. You can skip the keywords and
   use the same lib with callbacks.

## Done

- [x] [docs/README.md](../docs/README.md) — Start-here row + sentence
  that keeps the split
- [x] [029](029-async-event-loop.md) points at the map

## Out of scope

- A dedicated `docs/async.md`
- Changing the compiler or the `eventloop` package
