# 060 — ~~KV map (hash map)~~

**Status:** ❌ struck — hidden resize
([125](125-drop-host-json-sqlite.md))

A growing map (`m[k] = v` past capacity) reallocates: new buffer,
copy, free. That cost is not in the assignment. Same sin in the
grammar (`map[K]V`) and in a `$fn` stdlib that grows. Klin will
not ship either.

Do not reopen as “small map”, `stdlib/map`, or a `klin-lang/uthash`
wrapper. That is 050/060 through the back door.

## Instead (do this)

| Situation | Do | Cost |
|---|---|---|
| Firmware / closed set, keys known at compile time | `obj.field` or `table[Enum.x]` | one load |
| Closed set, key at runtime (id, code) | sorted `[N]T` + binary search you own | `O(log n)`, capacity = `N` |
| Host, dynamic strings, many keys | `@[cimport]` **uthash** (or khash) **in that program** | C `malloc` = C contract |

Example: [`examples/sorted_lookup.kl`](../examples/sorted_lookup.kl)
(enum index + owned bsearch). No uthash in this repo.

## What “read, don’t search” was

Wanted: load an object as a field, not look up a key. That is a
struct / enum index — not a hash map. A map always hashes and
probes; resize makes it worse.
