# 121 — Map: async / event loop is a library, not the language

**Status:** ✅ done
**Depends on:** [116](116-docs-reorg.md), [029](029-async-event-loop.md)

## Problem

After the docs map ([116](116-docs-reorg.md)) a reader could still treat
`async` / `.await` as a language chapter (Node-style runtime). Klin has
**no** hidden scheduler ([00-idea.md](../docs/00-idea.md)). The executor
is [`eventloop`](https://github.com/klin-lang/eventloop); optional
`async` / `.await` is sugar over that explicit loop ([029](029-async-event-loop.md)).

## Done

- [x] [docs/README.md](../docs/README.md) — Start-here row + one sentence
  under language notes
- [x] [029](029-async-event-loop.md) points at the map

## Out of scope

- A dedicated `docs/async.md`
- Changing the compiler or the `eventloop` package
