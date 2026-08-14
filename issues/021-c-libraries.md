# 021 — C libraries (FFI / link)

**Status:** ✅ done
**Depends on:** 006 (modules), attributes from 010

## MVP scope

- explicit `@[cimport]` with types (arity + argument/return types)
- `@[cheader]` + `@[cimport]` — declaration from C header (no prototype in emission;
  SVD accessors)
- `@[cinclude]` → `#include` in emission (no C header parser)
- `@[link("…")]` passed to host `cc` on `klin run` / `klin test`
  - string starting with `-` → flag as-is (`-lm`, `-L…`)
  - otherwise → path `.a` / `.o` / `.so` / `.s` / `.S` relative to `.kl` directory
    (ASM → [022](022-asm-libraries.md))
- CLI: `-l <name>`, `-L <dir>` (also glued `-lm`, `-L/path`)
- unknown calls = checker error, **except** host builtins `puts` / `printf`
- example: [`examples/ffi_add/`](../examples/ffi_add/)
- note: [`docs/09-ffi-c.md`](../docs/09-ffi-c.md)
- map: [docs/README.md](../docs/README.md) Start here (C / ASM) — [124](124-docs-c-asm.md)

Prime rule test: FFI does not hide allocation or ownership — user's
contract with C.

HAL (STM32Cube / LL) → [031](031-hal-libraries.md).

## Out of scope / later

- Full C header parser
- Klin libraries → [020](020-klin-libraries.md) ✅
- ASM units (`.s` via `@[link]`) → [022](022-asm-libraries.md) ✅
- Project manifest (JSON/toml) instead of attrs + CLI
- `cexport` → [045](045-cexport.md) ✅
- rpath / `LD_LIBRARY_PATH`
- Full varargs typing (`printf`) beyond builtins allowlist
