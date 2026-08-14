# 125 — Drop host JSON / SQLite / ORM from the Klin backlog

**Status:** ✅ done
**Depends on:** [050](050-sqlite-wrapper.md), [051](051-json-wrapper.md),
[070](070-host-orm-sqlite.md), [018](018-generators-yield.md)

## Verdict

Those packages are **host app stack**, not the language. Anyone who
needs them can `@[cimport]` cJSON / sqlite3. Klin will not ship
`import json` / `import sqlite` or an ORM as planned work.

JS-style `yield` is the same class of no: hidden frame / second
state machine next to `async` / `.await`. An iterator is a struct
with `next()` — no new keyword ([018](018-generators-yield.md)).

## Done

- [x] [050](050-sqlite-wrapper.md) / [051](051-json-wrapper.md) /
  [070](070-host-orm-sqlite.md) — ❌ not doing
- [x] [018](018-generators-yield.md) — no `yield` in the core
- [x] [sorted.md](sorted.md)

## Out of scope

- Deleting the issue files (the decision stays)
- Changing the compiler
- Forbidding a third-party FFI wrapper
