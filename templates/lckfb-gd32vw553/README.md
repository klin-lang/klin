# LCKFB GD32VW553 blink (`klin init`)

Scaffold from `klin init lckfb-gd32vw553`. Layout:
[054](../../issues/054-embedded-project-layout.md) /
[075](../../issues/075-board-pack-init-host.md). Board notes:
[156](../../issues/156-board-lckfb-gd32vw553.md).

Silk **`GD32VW553HMQ-EVT`** — stamp module with CH340 USB-C and external
JTAG. **Not** official START / EVAL (those have different LED maps).

Freestanding `board/startup.S` + `board/linker.ld` (Nuclei N307). Wi‑Fi is
a separate package — [`gd32v_wifi`](https://github.com/klin-lang/gd32v_wifi)
[137](../../issues/137-gd32v-wifi-sdk.md).

## Layout

```text
.
  main.kl              # app (user LED / PC13)
  board/
    startup.S          # Reset → main (no ECLIC)
    linker.ld          # 4M flash / 320K RAM (HMQ)
  Makefile
  klin.mod             # machine_gd32v
  README.md
```

Edit `main.kl` — you should not need to touch `board/` for a blink.

Pins (LCKFB wiki): LED **PC13**, KEY **PA0**, USB log USART0 **PB15/PA8**
(CH340). PWR LED is power-only.

## How

```sh
klin get                    # once — packages into $KLIN_CACHE
make emit KLIN=/path/to/bin/klin.dart   # or installed `klin`
make elf                    # needs riscv64-unknown-elf-gcc
```

Flash with external JTAG (OpenOCD / J-Link) on the 6-pin header, or UART
download with **BOOT0** held. Klin does not flash the chip.

## Links

- Issue [156](../../issues/156-board-lckfb-gd32vw553.md), [075](../../issues/075-board-pack-init-host.md), [136](../../issues/136-machine-gd32v-gd32vw553.md)
- Wiki: https://wiki.lckfb.com/zh-hans/gd32vw553/
- Chip: https://github.com/klin-lang/machine_gd32v
- EVAL / START (different boards): [138](../../issues/138-board-gd32vw553h-eval.md), [139](../../issues/139-board-gd32vw553h-start.md)
