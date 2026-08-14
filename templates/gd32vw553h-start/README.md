# GD32VW553 START blink (`klin init`)

Scaffold from `klin init gd32vw553h-start`. Layout:
[054](../../issues/054-embedded-project-layout.md) /
[075](../../issues/075-board-pack-init-host.md). Board pack:
[129](../../issues/129-board-gd32vw553h-start.md).

Freestanding `board/startup.S` + `board/linker.ld` (Nuclei N307). Wi‑Fi is
a separate package — [`gd32v_wifi`](https://github.com/klin-lang/gd32v_wifi)
[126](../../issues/126-gd32v-wifi-sdk.md).

## Layout

```text
.
  main.kl              # app (RGB red / PB0, AN154 V4)
  board/
    startup.S          # Reset → main (no ECLIC)
    linker.ld          # 2M flash / 256K RAM
  Makefile
  klin.mod             # machine_gd32v + gd32vw553h_start
  README.md
```

Edit `main.kl` — you should not need to touch `board/` for a blink.

## How

```sh
klin get                    # once — packages into $KLIN_CACHE
make emit KLIN=/path/to/bin/klin.dart   # or installed `klin`
make elf                    # needs riscv64-unknown-elf-gcc
```

Flash with OpenOCD / GDLINK. Klin does not flash the chip.

Not EVAL (USART0 PB15/PA8, LEDs PA4/PA5/PA6). START log UART is UART2 PA6/PA7.

## Links

- Issue [129](../../issues/129-board-gd32vw553h-start.md), [075](../../issues/075-board-pack-init-host.md), [117](../../issues/117-machine-gd32v-gd32vw553.md)
- Pack: https://github.com/klin-lang/gd32vw553h_start
- Chip: https://github.com/klin-lang/machine_gd32v
