# 060 — KV map (hash map)

**Status:** `map[K]V` in the grammar ❌ struck; stdlib / `$fn` 💭
([125](125-drop-host-json-sqlite.md))
**Depends on:** [007](007-pointers-arrays-slices.md); heap:
[057](057-allocator.md)

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
