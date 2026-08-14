# 118 — User doc: `klin init` walkthrough (not STM32-only)

**Status:** ✅ done
**Depends on:** [116](116-docs-reorg.md), [075](075-board-pack-init-host.md), [054](054-embedded-project-layout.md)

## Problem

After the docs map, MCU onboarding was still “look under `examples/stm32/`
and `templates/`”. The recipe is the same on Pico, Pico 2, Waveshare
RP2350-LCD, and ESP32-S3-Pico: `klin init` → `klin get` → board
toolchain. That spacer was missing.

## Done

- [x] [docs/embedded.md](../docs/embedded.md) — one recipe, Pico as the
  walked example, table of all `knownInitBoards`, ESP-IDF as a delta
- [x] Map / guide / README / CLI / examples point at it

## Out of scope

- Host `klin init` (still 💭 in 075)
- New boards or codegen
- SVD fluent API (that is [117](117-docs-device.md) / [device.md](../docs/device.md))
