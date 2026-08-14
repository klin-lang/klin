# Blink on a board (`klin init`)

Host programs are `klin run` and libc. Firmware is a **board scaffold**:
startup, linker (or a vendor SDK), then your `.kl`. Klin does not invent
a linker script from the chip name.

`klin init <board>` copies a bundled template. Same three steps on every
supported board — STM32 is one row, not the path.

```sh
klin init pico my_blink
cd my_blink
klin get
make
# → main.elf
```

From a clone, before `brew install`:

```sh
dart run /path/to/klin/bin/klin.dart init pico my_blink
cd my_blink
make get KLIN=/path/to/klin/bin/klin.dart
make KLIN=/path/to/klin/bin/klin.dart
```

`init` is a **local copy** from `templates/<board>/`. It does not hit
the network and it refuses a non-empty destination. Default `[dir]` is
`./<board>`.

`klin get` then fills `$KLIN_CACHE` from `klin.mod` (packages and,
on Nucleo, the SVD). Compile / `make` stay offline after that.

## Boards

| `klin init …` | Chip | Toolchain | Scaffold does |
|---|---|---|---|
| `nucleo-f411` | STM32F411RE | `arm-none-eabi-gcc` | PA5 LED via `$device` + `$board` |
| `pico` | RP2040 | `arm-none-eabi-gcc` | GPIO25 LED via `machine_rp` |
| `pico2` | RP2350 (Arm) | `arm-none-eabi-gcc` | GPIO25 LED via `machine_rp` (not Hazard3) |
| `waveshare-rp2350-lcd-096` | RP2350 | `arm-none-eabi-gcc` | LCD backlight via board pack |
| `waveshare-esp32-s3-pico` | ESP32-S3 | ESP-IDF v5.x | D10 LED via `machine_esp` + IDF |

Unknown id → error. Templates ship **in the Klin install**
(`templates/`, `$KLIN_TEMPLATES`, or `share/klin/templates` next to
the binary) — [06-cli.md](06-cli.md).

There is **no** `klin init` without a board (host hello + `klin.mod`
is still “copy `examples/hello.kl`”).

## Walkthrough: Pico

Needs `klin` (or `dart run bin/klin.dart`) and `arm-none-eabi-gcc` on
`PATH`.

```sh
klin init pico my_blink
cd my_blink
klin get                 # machine_rp → cache + klin.lock
make                     # --emit-c → arm-none-eabi-gcc → main.elf
```

Layout after init:

```text
my_blink/
  main.kl           # you edit this
  board/
    startup.s
    linker.ld
    boot2_w25q080.S # RP2040 second-stage boot
  Makefile
  klin.mod
  README.md
```

Edit `main.kl`. Leave `board/` alone for a blink. Flash with your usual
UF2 / picotool flow — Klin does not flash the chip.

Pico 2 is the same recipe (`klin init pico2`) with `image_def.S` instead
of `boot2_*.S`. Arm core only.

## Same recipe, other trees

**Nucleo-F411RE** — same `get` + `make`, Cortex-M4 flags. `main.kl` uses
`$device` + `$board` (typed registers, not `machine_*`). Registers:
[device.md](device.md).

```sh
klin init nucleo-f411 my_nucleo
cd my_nucleo && klin get && make
```

**Waveshare RP2350-LCD-0.96** — same Arm GNU recipe; the app toggles
the backlight, not GPIO25.

**Waveshare ESP32-S3-Pico** — **not** freestanding `startup.s` /
`linker.ld`. Boot and flash are ESP-IDF. The Klin steps stay `init` +
`get` + emit:

```sh
klin init waveshare-esp32-s3-pico my_esp
cd my_esp
. $IDF_PATH/export.sh    # ESP-IDF v5.x
klin get
make emit
make build
make flash
```

USB-C on that board is a CH343 UART. Edit `main.kl`; keep `main/app_main.c`
unless you are changing the IDF entry.

## What you do not do

- Import host stdlib (`io`, `mem`, `time`) on these scaffolds — they
  pull libc.
- Expect `klin run` to produce a `.elf` for the MCU. `run` is host CRT.
- Expect Klin to write `linker.ld` from the SVD. `$device` is MMIO,
  not the memory map ([device.md](device.md) / [075](../issues/075-board-pack-init-host.md)).
- Use HAL / Cube / IDF *as the Klin language*. Those stay C +
  `@[cimport]` or the board’s Makefile glue
  ([09-ffi-c.md](09-ffi-c.md)).

## Next

Path: [guide.md](guide.md) → [device.md](device.md) → here.

| | |
|---|---|
| Language (host) | [guide.md](guide.md) |
| Registers / `$device` | [device.md](device.md) |
| FreeRTOS tasks | [`klin_freertos`](https://github.com/klin-lang/klin_freertos) (kernel stays C) — [`examples/stm32/freertos_blink/`](../examples/stm32/freertos_blink/) |
| Per-board README | [`templates/`](../templates/) |
| Older in-tree STM32 sketches | [`examples/stm32/`](../examples/stm32/) |
| Why packs exist | [075](../issues/075-board-pack-init-host.md), [054](../issues/054-embedded-project-layout.md) |
