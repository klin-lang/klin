# FreeRTOS blink — Nucleo-F411RE (issue 028)

Board-shaped demo: **`klin_freertos` + `machine_stm32`**, ≥2 tasks, LED on **PA5**.

## Layout ([054](../../../issues/054-embedded-project-layout.md))

| Piece | Role |
|---|---|
| `main.kl` | `$rtos_task` blink + heartbeat |
| `board/` | `startup.s` / `linker.ld` (F411 pack; weak SysTick for FreeRTOS) |
| `Makefile` | thin; includes `../_common/f411.mk` |
| `FreeRTOSConfig.h` | board config for `make elf` (not used by stubs) |
| `freertos_stubs/` | emit-c / object compile without a kernel |
| `ref/blink_ref.c` | C twin for overhead compare |

## Prerequisites

```sh
# from this directory
dart run ../../../bin/klin.dart get
```

Pins (`klin.mod`): `klin_freertos@v0.3.0`, `machine_stm32@v0.5.0`.

Toolchain: `arm-none-eabi-gcc`.

## Emit / compile check (stubs) — default CI path

```sh
make KLIN=/path/to/klin/bin/klin.dart
# → out/main.c out/main.o
```

This does **not** link a scheduler. Stubs stand in for FreeRTOS headers only.

## Board ELF (real FreeRTOS)

1. Clone [FreeRTOS-Kernel](https://github.com/FreeRTOS/FreeRTOS-Kernel) (or use a
   vendor pack with **GCC/ARM_CM4F**).
2. This folder already has `FreeRTOSConfig.h` (HSI 16 MHz, 1 kHz tick, 16 KiB
   heap — tune after PLL / clock setup).
3. The FreeRTOS port provides **SVC / PendSV / SysTick** (`FreeRTOSConfig.h`
   aliases the handlers; `board/startup.s` weak defaults are overridden at link).
4. Link **without** `freertos_stubs` on `-I`:

```sh
make elf FREERTOS_DIR=/path/to/FreeRTOS-Kernel KLIN=…
# → main.elf
```

Adjust the `elf` recipe’s source list if your tree layout differs. Flash with
OpenOCD / probe-rs / STM32CubeProgrammer.

## Overhead vs C (issue 028)

Hand-written twin: [`ref/blink_ref.c`](ref/blink_ref.c). Same FreeRTOS tree / flags:

```sh
make compare FREERTOS_DIR=/path/to/FreeRTOS-Kernel KLIN=…
# → main.elf, blink_ref.elf, overhead.md
```

Snapshot: [`overhead.md`](overhead.md) — `task_heartbeat` is **12 bytes** on both
(direct `vTaskDelay` loop); whole `.text` differs by tens of bytes (Pin helpers
vs inlined MMIO), not a Klin scheduler tax.

## Contract

- No hidden allocation in Klin: stacks/prios are explicit in `$rtos_task`.
- GPIO stays in `machine_stm32`; RTOS stays in `klin_freertos`.
- FromISR / idle wake: separate APIs (`klin_freertos` `@v0.3.0`) — not this demo.

## Links

- Issue: [028](../../../issues/028-freertos.md), [054](../../../issues/054-embedded-project-layout.md)
- Packages: [klin_freertos](https://github.com/klin-lang/klin_freertos),
  [machine_stm32](https://github.com/klin-lang/machine_stm32)
- Bare-metal Pin blink (no RTOS): [`../blink_f411/`](../blink_f411/),
  [machine_stm32 examples/blink_f411](https://github.com/klin-lang/machine_stm32/tree/main/examples/blink_f411)
