# 060 — KV map (hash map)

**Status:** `map[K]V` in the grammar ❌ struck; stdlib / `$fn` 💭
([125](125-drop-host-json-sqlite.md))
**Depends on:** [007](007-pointers-arrays-slices.md); heap:
[057](057-allocator.md)

## What “read, don’t search” is

Wanted: load an object **as a field**, not look up a key.
That is a **fixed layout**, not a hash map.

| Keys known when? | Mechanism | Cost |
|---|---|---|
| Compile time (fields, registers, closed set) | `obj.field`, `table[Enum.x]`, kv-enum ([072](072-enums.md)) | one load / index — `objdump` matches C |
| Runtime (`str` from UART, id from packet) | you **must** search: `$fn` map, `bsearch`, or C uthash | hash + probe, or log n |

A hash map always searches. `m[k] = v` / `m[k]` is not “just read.”
On MCU it is often slower than a struct (branches, cache). Do not
use 060 for the first row.

## Struck: `map[K]V` in the language

Go/V builtin (`m[k] = v` grows the heap). C has no such type.
Hidden resize, key ownership, and a runtime map break the prime
rule. Do not add `map[K]V` to the grammar. Do not reopen as
“small builtin.”

## Still open: map as `$fn` / stdlib (like `slice`)

Same honesty as [017](017-collection-methods.md):

- layer 1 — fixed capacity / caller buffer (bare-metal OK)
- layer 2 — explicit `Allocator` (`put` / grow visible)
- names like `map_i32` until [034](034-generic-types.md) has 2–3
  hard `$fn` places (this would be one)

FFI to uthash/khash is an app choice (`@[cimport]`), not a Klin
package on the backlog ([050](050-sqlite-wrapper.md) is ❌).

Embedded without a general heap map: array + `bsearch` / perfect
hash.

## Out of scope

- `map[K]V` syntax / hidden grow
- ordered map / tree as MVP
- implementation in this issue (placeholder for the `$fn` track)
