# STM32 board examples

Bare-metal demos under `stm32/<name>/` — host `klin run` is **not** enough;
each folder has `startup.s`, `linker.ld`, and a Makefile for
`arm-none-eabi-gcc`.

## What

| Path | Notes |
|---|---|
| [`blink_f411/`](blink_f411/) | Nucleo-F411RE LED — local SVD via `$peripherals_from_svd` |
| [`device_f411/`](device_f411/) | Same blink — remote `$device` + `klin get` ([053](../../issues/053-device-board-assets.md)) |
| [`freertos_blink/`](freertos_blink/) | FreeRTOS ≥2 tasks + PA5 via `machine_stm32` ([028](../../issues/028-freertos.md)) |

## Why

Board packs keep startup/linker next to the app ([075](../../issues/075-board-pack-init-host.md)).
Host CRT demos stay at `examples/*.kl` / non-`stm32/` folders.
Fresh project: `klin init nucleo-f411` (bundled `templates/nucleo-f411/`).

## How

See each subdirectory README (`make` after toolchain install).
Scaffold: `dart run bin/klin.dart init nucleo-f411 my_blink` then
`cd my_blink && dart run … get && make`.

## Links

- [issues/075](../../issues/075-board-pack-init-host.md)
- [docs/04-macros.md](../../docs/04-macros.md) (SVD / `$device`)
- Catalog: [`../README.md`](../README.md)
