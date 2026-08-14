# 070 — ORM-like / typed repo over SQLite (host)

**Status:** ❌ not doing — depends on [050](050-sqlite-wrapper.md);
host ORM is the opposite of the C-wedge thesis
([125](125-drop-host-json-sqlite.md))
**Depends on:** [050](050-sqlite-wrapper.md) (thin FFI), [021](021-c-libraries.md);
  optionally [026](026-preprocessor.md) / [057](057-allocator.md)

## Context

Goal: applications on **host machines** (desktop / server / Linux), not bare-metal.
Avoid hand-gluing SQL everywhere — without porting Hibernate to C.

Pure C has almost no full ORMs (no reflection / generics). Sensible
SQLite ORMs are usually in **C++** (`sqlite_orm`, sqlpp11, ODB). Klin compiles
to C → natural path is **sqlite3 C API** + Klin layer, not C++ binding.

Embedded: only when there is OS + heap + FS (e.g. RPi / SBC with Linux ≈ host).
Classic STM32 without heap — outside this issue (SQLite mallocates internally anyway).

## Direction (not classic ORM)

1. **Layer 0** — [050](050-sqlite-wrapper.md): `open` / `prepare` / `bind` /
   `step` / `close`, link `-lsqlite3`.
2. **Layer 1 (this issue)** — typed helpers / “repo”:
   - codegen from schema (`.sql` / declarations) **or** `$fn` (D3) generating
     `insert` / `get_by_id` / simple `query_*` for concrete structs;
   - ownership and allocation **explicit** (`Allocator` / caller buffers / C contract);
   - `defer` on caller side — no autofree / RAII.
3. **Do not promise** magic `users.filter(u => u.age > 18)` without SQL or
   without a custom DSL + codegen.

Usage sketch (host):

```klin
let db = sqlite.open("app.db")!
defer db.close()
let u = user_repo.get(db, id)!   // generated / $fn — typed, not raw SQL everywhere
```

## Out of scope

- rewriting SQLite in Klin
- full ORM like EF / Hibernate / Luxon-style lazy
- porting a C++ ORM to Klin
- bare-metal / VFS on MCU (separate decision; not priority)
- priority over language core, embedded LED, basic FFI

## Criteria (when implementation happens)

- [ ] Docs: layer 0/1 model + ownership
- [ ] Dependency on working 050 wrapper
- [ ] Host example + golden tests (deterministic, no “live” internet)
- [ ] Zero hidden allocation on Klin API side (SQLite malloc = C contract)
