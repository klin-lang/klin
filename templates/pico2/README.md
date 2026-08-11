# Raspberry Pi Pico 2 / RP2350 (Arm) blink (`klin init`)

Scaffold from `klin init pico2`. Layout:
[054](../../issues/054-embedded-project-layout.md) /
[075](../../issues/075-board-pack-init-host.md). Chip API:
[`machine_rp`](https://github.com/klin-lang/machine_rp).

## Layout

```text
.
  main.kl              # app (GPIO25 LED)
  board/
    startup.s
    linker.ld
    image_def.S        # RP2350 PICOBIN IMAGE_DEF
  Makefile
  klin.mod
  README.md
```

## How

```sh
klin get
make KLIN=/path/to/bin/klin.dart
# → main.elf
```

Needs `arm-none-eabi-gcc` on `PATH`. Arm core only (not Hazard3 RISC-V).

## Links

- [075](../../issues/075-board-pack-init-host.md), [062](../../issues/062-targets-esp-rp.md)
- Sibling: [`machine_rp` `examples/blink_pico2`](https://github.com/klin-lang/machine_rp/tree/main/examples/blink_pico2)
