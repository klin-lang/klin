# STM32 board examples

Bare-metal demos under `stm32/<name>/` — host `klin run` is **not** enough.
Convention ([054](../../issues/054-embedded-project-layout.md)):

```text
stm32/<demo>/
  main.kl              # app (low noise)
  board/               # startup.s, linker.ld — not in the demo root
  Makefile             # thin; include ../_common/f411.mk
  …                    # klin.mod, FreeRTOSConfig.h, ref/, …
stm32/_board/nucleo-f411/   # canonical F411 pack (copied into each demo board/)
stm32/_common/f411.mk       # shared CC / freestanding flags
```

## What

| Path | Notes |
|---|---|
| [`blink_f411/`](blink_f411/) | Nucleo-F411RE LED — local SVD via `$peripherals_from_svd` |
| [`device_f411/`](device_f411/) | Same blink — remote `$device` + `klin get` ([053](../../issues/053-device-board-assets.md)) |
| [`freertos_blink/`](freertos_blink/) | FreeRTOS ≥2 tasks + PA5 via `machine_stm32` ([028](../../issues/028-freertos.md)) |

## Why

Board packs keep startup/linker next to the app, under `board/`
([075](../../issues/075-board-pack-init-host.md), [054](../../issues/054-embedded-project-layout.md)).
Host CRT demos stay at `examples/*.kl` / non-`stm32/` folders.
Fresh project: [docs/embedded.md](../../docs/embedded.md) —
`klin init nucleo-f411` (or `pico`, ESP, …).

## How

See each subdirectory README (`make` after toolchain install).
Scaffold: `dart run bin/klin.dart init nucleo-f411 my_blink` then
`cd my_blink && dart run … get && make`.

## Links

- [issues/054](../../issues/054-embedded-project-layout.md), [075](../../issues/075-board-pack-init-host.md)
- [docs/embedded.md](../../docs/embedded.md) (`klin init`)
- [docs/device.md](../../docs/device.md) (SVD / `$device` / fluent MMIO)
- Catalog: [`../README.md`](../README.md)
