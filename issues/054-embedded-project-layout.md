# 054 — Embedded project layout / appearance

**Status:** ✅ `examples/stm32/` layout + shared Make + `klin init`  
**Depends on:** [023](023-examples.md) (`examples/stm32/` layout), [010](010-bare-metal.md);
nice to have [053](053-device-board-assets.md) (clean `$device`), [022](022-asm-libraries.md);
other MCU families: [062](062-targets-esp-rp.md)

## Problem

Previously [`examples/stm32/blink_f411/`](../examples/stm32/blink_f411/) mixed Klin
source with `startup.s` / `linker.ld` / C refs in one flat directory — toolchain
noise over the app.

## Goal

A clear freestanding layout where:

1. the app is mainly `main.kl` (or few Klin files) + `import` / `$device`
2. linker / startup / shared Make live in `board/` / `_common/` — not in the
   demo root
3. `klin init` (or copyable Nucleo-F411 template) generates this layout

Settled layout:

```text
examples/stm32/<demo>/
  main.kl
  board/               # startup.s, linker.ld
  Makefile             # include ../_common/f411.mk
  ref/…                # optional C twin
examples/stm32/_board/nucleo-f411/   # canonical pack (copied into demo board/)
examples/stm32/_common/f411.mk
```

Startup stays raw `.s` ([010](010-bare-metal.md)) — location only, not Klin magic.

## Evolution sketch

1. Settled directory convention + blink refactor (docs `examples/README.md`) — ✅
2. Shared Make rules for ARM (`_common/f411.mk`) — ✅
3. `klin init nucleo-f411` — ✅ [075](075-board-pack-init-host.md)

## What not to do

- full IDE / CubeMX plugin / graphical wizard
- wrapping the vector table in “magic” Klin ([010](010-bare-metal.md))
- changing `import` / FFI semantics just to hide files
- promising HAL through layout — that is [031](031-hal-libraries.md)

## Criteria

- [x] blink (and siblings) readable: Klin app separate from linker/startup
- [x] ARM build without regression (elf / `SysTick_Handler` as today)
- [x] `examples/README.md` / `examples/stm32/README.md` describe the convention
- [x] `klin init <board>` — bundled `templates/` ([075](075-board-pack-init-host.md))

## Related

- [010](010-bare-metal.md) / [023](023-examples.md) — bare metal + `examples/stm32/`
- [022](022-asm-libraries.md) — `@[link]` / `out/*.link`
- [053](053-device-board-assets.md) — clean device / SVD
- [075](075-board-pack-init-host.md) — board pack / init vs host (linker & startup)
- [028](028-freertos.md) — `freertos_blink/` under this convention
