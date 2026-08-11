# 054 — Embedded project layout / appearance

**Status:** 💭 under consideration
**Depends on:** [023](023-examples.md) (`examples/stm32/` layout), [010](010-bare-metal.md);
nice to have [053](053-device-board-assets.md) (clean `$device`), [022](022-asm-libraries.md);
other MCU families: [062](062-targets-esp-rp.md)

## Problem

Today [`examples/stm32/blink_f411/`](../examples/stm32/blink_f411/) in one directory
mixes:

- Klin source (`blink.kl`) with a long path to SVD
- boilerplate: `startup.s`, `linker.ld`, `Makefile`
- C reference (`blink_ref.c`)
- generated `*_regs.h` / `*_regs.kl`

For someone opening a “Klin project on Nucleo”, it looks like a pile of
toolchain files, not a small app. [023](023-examples.md) only established
`stm32/<name>/` — no “app vs board vs vendor” convention or scaffold.

[053](053-device-board-assets.md) improves **code** UX (SVD / fetch); this issue
= **directory and project template** UX.

## Goal

A clear freestanding layout where:

1. the app is mainly `main.kl` (or few Klin files) + `import` / `$device`
2. linker / startup / shared Make live in `board/` / `vendor/` / shared
   target — not “shouting” in the demo root
3. optionally `klin init` (or copyable Nucleo-F411 template) generates this layout

Sketch (orientational, not spec):

```
blink_f411/
  main.kl              # or blink.kl — low noise
  board/               # startup.s, linker.ld, pinout / constants
  Makefile             # thin; include shared freestanding rules
```

Or shared `examples/stm32/_common/` + demos with only `main.kl` + short Make.

Startup can still be raw `.s` ([010](010-bare-metal.md)) — the point is
**where it lives**, not hiding it in Klin magic.

## Evolution sketch

1. Settled directory convention + blink refactor (docs `examples/README.md`)
2. Shared Make rules / script for ARM (no language semantics change)
3. Optionally: `klin init nucleo-f411` (or repo template) — after [053](053-device-board-assets.md)
   more sensible (`$device` instead of `../../../third_party/...`).
   Host vs MCU takeaways + **three layers** (pack / init / `board`+.ioc):
   [075 §1b](075-board-pack-init-host.md).

## What not to do

- full IDE / CubeMX plugin / graphical wizard
- wrapping the vector table in “magic” Klin ([010](010-bare-metal.md))
- changing `import` / FFI semantics just to hide files
- promising HAL through layout — that is [031](031-hal-libraries.md)

## Criteria (when work starts)

- [ ] blink (or new template) readable: Klin app separate from linker/startup
- [ ] ARM build without regression (elf / `SysTick_Handler` as today)
- [ ] `examples/README.md` describes the convention
- [x] (optional) `klin init nucleo-f411` — bundled `templates/nucleo-f411/` ([075](075-board-pack-init-host.md))

## Related

- [010](010-bare-metal.md) / [023](023-examples.md) — bare metal + `examples/stm32/`
- [022](022-asm-libraries.md) — `@[link]` / `out/*.link`
- [053](053-device-board-assets.md) — clean device / SVD
- [075](075-board-pack-init-host.md) — board pack / init vs host (linker & startup)
- [028](028-freertos.md) — further demos under this convention too
