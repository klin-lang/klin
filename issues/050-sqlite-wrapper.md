# 050 — SQLite wrapper in a Klin module

**Status:** ❌ not doing — host app stack, not Klin
([125](125-drop-host-json-sqlite.md))
**Depends on:** [021](021-c-libraries.md); nice to have [020](020-klin-libraries.md) / [047](047-directory-modules.md)

Anyone who wants SQLite `@[cimport]`s `sqlite3`. This repo will not
ship `import sqlite` as planned work.

## Context

SQLite stays a **C** library. Klin can provide a thin module (`import sqlite`)
with `@[cimport]` / `@[cinclude]` / `@[link]` — do not port the engine to Klin.

## Sketch (later)

- package `sqlite/` or `sqlite.kl`: FFI declarations + `pub` API (open / exec / …)
- link `-lsqlite3` or amalgamation `.c` via `@[link]`
- host example; bare-metal only with explicit VFS/FS (out of MVP for this issue)

SQLite allocation = explicit C contract, not hidden Klin magic.

## Out of scope

- rewriting SQLite in Klin
- ~~ORM / typed repo~~ → [070](070-host-orm-sqlite.md) (❌ struck, not “later”)
- priority relative to language core / embedded LED / basic FFI
