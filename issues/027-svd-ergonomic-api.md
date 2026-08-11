# 027 — Ergonomic SVD API (`$peripherals_from_svd` / fluent)

**Status:** ✅ done
**Depends on:** 011 (emitter / zero-cost MMIO) + 026 (preprocessor)

## Goal

From [011](011-svd.md): `$peripherals_from_svd("…")` and fluent-style syntax
`RCC.AHB1ENR.GPIOAEN.set(1)` / `.write(.Output)` / `.toggle()`.

Do not duplicate SVD parser — reuse `svd2klin` / shared `lib/svd`.

## MVP (done)

- Built-in `$peripherals_from_svd("path.svd"[, "RCC,GPIOA,STK"])` in preprocessor
  (`lib/svd/fluent.dart` + `lib/preprocess.dart`)
- Write `{stem}_regs.h` / `.kl` next to source + `@[cinclude(…)]`
- Fluent rewrite → existing `PERIPH_REG_FIELD_{set,write,toggle}`
  (still `static inline` in C → no `bl` to accessors)
- `.EnumName` as sole argument → literal from SVD (`write(.Output)` → `write(1)`)
- Blink: [`examples/stm32/blink_f411/main.kl`](../examples/stm32/blink_f411/main.kl)

## Auto-gen on compile (later)

If source declares chip/SVD, and generated artifact does not exist or
is older than SVD — `klin` runs the same codegen as `svd2klin`
(in-process lib), then parse/check/emit. Cache by mtime/hash; flag
`--no-gen` when needed. Outside MVP — Makefile + manual `svd2klin` still OK;
`$peripherals_from_svd` already generates at preprocess time.

## Criteria

- [x] Blink on nice syntax
- [x] objdump: no `bl` to `RCC_*` / `GPIOA_*` / `STK_*` accessors

## Later

Clean UX + Go-like SVD fetch (`$device("github/…/….svd")`, cache, board
packages): [053](053-device-board-assets.md).
