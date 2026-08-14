# GD32VW553H-EVAL blink (`klin init`)

Scaffold from `klin init gd32vw553h-eval`. Layout:
[054](../../issues/054-embedded-project-layout.md) /
[075](../../issues/075-board-pack-init-host.md). Board pack:
[138](../../issues/138-board-gd32vw553h-eval.md).

Freestanding `board/startup.S` + `board/linker.ld` (Nuclei N307). Wi‑Fi is
a separate package — [`gd32v_wifi`](https://github.com/klin-lang/gd32v_wifi)
[137](../../issues/137-gd32v-wifi-sdk.md).

## Layout

```text
.
  main.kl              # app (LED1 / PA4)
  board/
    startup.S          # Reset → main (no ECLIC)
    linker.ld          # 2M flash / 256K RAM
  Makefile
  klin.mod             # machine_gd32v + gd32vw553h_eval
  README.md
```

Edit `main.kl` — you should not need to touch `board/` for a blink.

## How

```sh
klin get                    # once — packages into $KLIN_CACHE
make emit KLIN=/path/to/bin/klin.dart   # or installed `klin`
make elf                    # needs riscv64-unknown-elf-gcc
```

Flash with OpenOCD / GD-Link. Klin does not flash the chip.

Not the START kit (SDK default UART2 PA6/PA7). EVAL COM0 is USART0 PB15/PA8.

## Links

- Issue [138](../../issues/138-board-gd32vw553h-eval.md), [075](../../issues/075-board-pack-init-host.md), [136](../../issues/136-machine-gd32v-gd32vw553.md)
- Pack: https://github.com/klin-lang/gd32vw553h_eval
- Chip: https://github.com/klin-lang/machine_gd32v
