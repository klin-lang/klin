# 125 — Drop host JSON / SQLite; strike map (hidden resize)

**Status:** ✅ done
**Depends on:** [050](050-sqlite-wrapper.md), [051](051-json-wrapper.md),
[060](060-map-kv.md)

## Verdict

Host app stack is not the language. Anyone who needs JSON or SQLite
`@[cimport]`s a C library. Klin will not ship `import json` /
`import sqlite`.

**Struck** (not deferred):

- KV map — grammar **and** `$fn` / stdlib. Grow on insert is a
  hidden resize (alloc + copy), not in the `=` / `put`.
  ([060](060-map-kv.md))

Instead: `obj.field` / `table[Enum.x]`; closed runtime keys → owned
bsearch ([`examples/sorted_lookup.kl`](../examples/sorted_lookup.kl));
host dynamic strings → uthash **in that program**, not a Klin package.

## Done

- [x] [050](050-sqlite-wrapper.md) / [051](051-json-wrapper.md) — ❌ not doing
- [x] [060](060-map-kv.md) — ❌ struck
- [x] [sorted.md](sorted.md)
- [x] [`examples/sorted_lookup.kl`](../examples/sorted_lookup.kl) — enum index + owned bsearch

## Out of scope

- Changing the compiler
- Forbidding a third-party FFI wrapper
