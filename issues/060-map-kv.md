# 060 — ~~KV map (hash map)~~

**Status:** ❌ struck — hidden resize
([125](125-drop-host-json-sqlite.md))

A growing map (`m[k] = v` past capacity) reallocates: new buffer,
copy, free. That cost is not in the assignment. Same sin in the
grammar (`map[K]V`) and in a “honest” `$fn` stdlib that grows.
Klin will not ship either.

Do not reopen as “small map” or “stdlib with visible Allocator grow.”
A grow is still a hidden branch + copy unless the caller writes the
new buffer themselves.

Fixed layout stays ordinary Klin: `obj.field`, `table[Enum.x]`,
kv-enum ([072](072-enums.md)). Runtime lookup is the caller’s C
(`@[cimport]` uthash) or a linear/`bsearch` they own.

## What “read, don’t search” was

Wanted: load an object as a field, not look up a key. That is a
struct / enum index — not a hash map. A map always hashes and
probes; resize makes it worse.
