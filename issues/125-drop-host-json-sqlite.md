# 125 — Drop host JSON / SQLite; strike ORM, `yield`, `map[K]V`

**Status:** ✅ done
**Depends on:** [050](050-sqlite-wrapper.md), [051](051-json-wrapper.md),
[070](070-host-orm-sqlite.md), [018](018-generators-yield.md),
[060](060-map-kv.md)

## Verdict

Host app stack is not the language. Anyone who needs JSON or SQLite
`@[cimport]`s a C library. Klin will not ship `import json` /
`import sqlite`.

**Struck** (not deferred):

- ORM — no typed repo, no query builder ([070](070-host-orm-sqlite.md))
- `yield` — no second suspend; iterator = struct with `next()`
  ([018](018-generators-yield.md))
- `map[K]V` in the grammar — hidden grow like Go
  ([060](060-map-kv.md))

**Still open:** a map as `$fn` / stdlib (fixed buffer or explicit
`Allocator`), like `slice`. That is not `map[K]V`.

## Done

- [x] [050](050-sqlite-wrapper.md) / [051](051-json-wrapper.md) — ❌ not doing
- [x] [070](070-host-orm-sqlite.md) / [018](018-generators-yield.md) — ❌ struck
- [x] [060](060-map-kv.md) — `map[K]V` ❌; `$fn` track 💭
- [x] [sorted.md](sorted.md)

## Out of scope

- Deleting the issue files (the decision stays)
- Changing the compiler
- Forbidding a third-party FFI wrapper
- Implementing `stdlib/map`
