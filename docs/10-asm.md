# ASM units and `asm("…")` (issue 022)

Raw `.s` / `.S` attached via existing `@[link]`, plus a GNU
`asm("…")` **string** in `.kl`. Neither is an ASM language in Klin.

## `.s` vs `.S`

C toolchain convention (gcc/clang):

| Extension | C preprocessor | Meaning |
|---|---|---|
| **`.s`** | no | File goes straight to assembler; `#if` / `#define` / `#include` do not work (or are plain text / error, depending on tool). |
| **`.S`** | yes (`cpp`, then assembler) | You can write `#if defined(__APPLE__)`, `#define SYM _foo`, `#include`. |

In Klin (`@[link]`) both are OK — it is just a path for `cc`. Choice depends on
whether you need the preprocessor.

Example [`examples/asm_add/add.S`](../examples/asm_add/add.S) uses uppercase `.S`
so the same file handles Apple (`_asm_add`) vs ELF (`asm_add`) and
aarch64 vs x86_64 via `#if`.

## Host

```klin
@[link("add.S")]
@[cimport, codename("asm_add")]
fn asm_add(a: i32, b: i32): i32
```

`klin run` passes the path to host `cc` (like `.a` / `.o`). Symbols:
Klin→ASM / C = `@[codename]` / `@[cexport]`; ASM→Klin = `@[cimport, codename]`.

Example: [`examples/asm_add/`](../examples/asm_add/).

## Bare-metal

`-T linker.ld` and `arm-none-eabi-*` stay in the Makefile. Klin with `--emit-c`
writes the `@[link]` list to `out/<base>.link`; Makefile links those files
alongside emitted `.c` (e.g. `startup.s` from STM32 blink).

## `asm("…")` in `.kl`

A statement, not an assembler. The string is copied into GNU
`asm volatile("…");` in the emitted `.c`. No operand / clobber
syntax in Klin — one string the C compiler accepts as basic `asm`.

```klin
fn wfi() {
    asm("wfi")
}
```

This is not an ASM DSL ([022](../issues/022-asm-libraries.md) still
holds: no assembler in the grammar). Whole functions stay in `.s` / `.S`.

## Out of scope

ABI per target, mangling without `codename`, an ASM language in `.kl`,
extended GNU operands as Klin syntax, CLI only for ASM.
C FFI in general: [09-ffi-c.md](09-ffi-c.md).
