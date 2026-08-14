# 125 — Drop host JSON / SQLite; strike ORM, `yield`, map (hidden resize)

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
- KV map — grammar **and** `$fn` / stdlib. Grow on insert is a
  hidden resize (alloc + copy), not in the `=` / `put`.
  ([060](060-map-kv.md))

Fast object reads stay `obj.field` / `table[Enum.x]`.

## Done

- [x] [050](050-sqlite-wrapper.md) / [051](051-json-wrapper.md) — ❌ not doing
- [x] [070](070-host-orm-sqlite.md) / [018](018-generators-yield.md) / [060](060-map-kv.md) — ❌ struck
- [x] [sorted.md](sorted.md)

## Out of scope

- Deleting the issue files (the decision stays)
- Changing the compiler
- Forbidding a third-party FFI wrapper
