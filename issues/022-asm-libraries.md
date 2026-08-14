# 022 — ASM libraries / units

**Status:** ✅ done
**Depends on:** [021](021-c-libraries.md) (`@[link]` / `cimport` / `codename`)

## MVP scope

- `.s` / `.S` as paths in `@[link("…")]` (reuse 021; no new attribute)
- symbols: Klin→ASM = `@[codename]` / `@[cexport]`; ASM→Klin = `@[cimport, codename]`
- host: `klin run` + test + [`examples/asm_add/`](../examples/asm_add/)
- bare-metal: blink `@[link("board/startup.s")]`; Makefile reads `out/*.link`
  (without moving `-T board/linker.ld` into Klin; layout [054](054-embedded-project-layout.md))
- note: [`docs/10-asm.md`](../docs/10-asm.md)
- map: [docs/README.md](../docs/README.md) Start here (C / ASM)

The `asm("…")` statement is a GNU **string** (`asm volatile` in the
`.c`), not the assembler this issue refused. Map: [124](124-docs-c-asm.md).

## What we are not doing

- DSL / assembler inside `.kl` (`asm("…")` is a string, not a language)
- ABI per target / mangling without `codename`
- CLI only for ASM
