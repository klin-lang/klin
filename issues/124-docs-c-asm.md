# 124 — Map: C FFI + ASM units / `asm("…")`, not a C/ASM language

**Status:** ✅ done
**Depends on:** [116](116-docs-reorg.md), [021](021-c-libraries.md),
[022](022-asm-libraries.md)

## Problem

Landing mentioned C FFI in one toolchain line. `09-ffi-c.md` and
`10-asm.md` lived only in the Tooling table. A reader looking for
“can I drop to C / ASM?” had no Start-here row, and `asm("…")`
(GNU string → `asm volatile`) was undocumented — `10-asm.md` even
read as “no assembler in `.kl`.”

Klin is not a C or ASM language. Drop-to-C is `@[cimport]` /
`@[cexport]` / `@[link]`, not a `c("…")` snippet. Drop-to-ASM is a
`.s` / `.S` unit or `asm("…")`.

## Done

- [x] [docs/README.md](../docs/README.md) — Start-here row + sentence
- [x] [docs/10-asm.md](../docs/10-asm.md) — `asm("…")` section
- [x] [docs/09-ffi-c.md](../docs/09-ffi-c.md) — no `c("…")` snippet
- [x] [docs/guide.md](../docs/guide.md) §10 + What next
- [x] Landing README — one ASM clause next to FFI
- [x] [00-idea.md](../docs/00-idea.md) non-goal
- [x] [examples/README.md](../examples/README.md) pointer
- [x] [021](021-c-libraries.md) / [022](022-asm-libraries.md) point at the map
- [x] [06-cli.md](../docs/06-cli.md) — ASM pointer next to FFI

## Out of scope

- A dedicated `docs/inline-asm.md`
- Extended GNU operands as Klin syntax
- A `c("…")` insert
- Changing the compiler
