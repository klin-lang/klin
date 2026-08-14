# 070 — ~~ORM-like / typed repo over SQLite~~

**Status:** ❌ struck — not Klin work, not “later”
([125](125-drop-host-json-sqlite.md))

No typed repo, no query builder, no codegen-from-schema, no
`$fn` `user_repo.get`. That is an application stack. Klin’s exit
hatch is C: `@[cimport]` sqlite3 if you want SQL.

[050](050-sqlite-wrapper.md) (thin `import sqlite`) is also ❌.
This issue does not wait on it.

## Historical sketch (not a plan)

Was: host-only layer over sqlite3 (`open` / `prepare` / generated
`insert` / `get_by_id`). Rejected with the host JSON/SQLite backlog.
Do not reopen as “small ORM” or “just a repo helper.”
