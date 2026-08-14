# 117 — User doc for SVD / `$device` / fluent MMIO

**Status:** ✅ done
**Depends on:** [116](116-docs-reorg.md), [011](011-svd.md), [027](027-svd-ergonomic-api.md), [053](053-device-board-assets.md)

## Problem

Typed registers from SVD are the MCU-side reason Klin exists (011).
After the docs map ([116](116-docs-reorg.md)) that story still lived in
issues and a stub in [04-macros.md](../docs/04-macros.md). A new reader
could not find `RCC.AHB1ENR.GPIOAEN.set(1)` without grepping `issues/`.

## Done

- [x] [docs/device.md](../docs/device.md) — user page (load SVD, fluent
  API, cost, `$device` vs `import`, `$board` pointer, not-list)
- [x] Map / guide / README / macros / libraries point at it
- [x] Examples keep working as the runnable proof

## Out of scope

- Embedded walkthrough (`klin init` → LED) — next docs gap
- New codegen / new SVD sources
- HAL ([031](031-hal-libraries.md))
