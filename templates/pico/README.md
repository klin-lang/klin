# Raspberry Pi Pico / RP2040 blink (`klin init`)

Scaffold from `klin init pico`. Layout:
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
    boot2_w25q080.S    # RP2040 second-stage boot
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

Needs `arm-none-eabi-gcc` on `PATH`.

## Links

- [075](../../issues/075-board-pack-init-host.md), [061](../../issues/061-micropython-machine-api.md)
- Sibling: [`machine_rp` `examples/blink_pico`](https://github.com/klin-lang/machine_rp/tree/main/examples/blink_pico)
