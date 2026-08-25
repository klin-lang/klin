# WeAct STM32F411CE Black Pill (`klin init`)

Scaffold from `klin init weact-f411`. Same F411-class map as Nucleo-F411RE
(512 K flash @ `0x08000000`, 128 K RAM). USB-C on this board is **device
USB**, not an ST-Link.

Shop example: [Elektroweb J-094](https://elektroweb.pl/pl/stm32/778-mikrokontroler-stm32f411ceu6-stm32-blackpill.html)
(WeAct-style F411CEU6). TFT + SD wiring: [`klin_st7735` G-176 example](https://github.com/klin-lang/klin_st7735/tree/main/examples/g176_blackpill).

Issue: [147](../../issues/147-board-weact-f411.md). Layout: [075](../../issues/075-board-pack-init-host.md).

## Layout

```text
.
  main.kl           # PC13 LED blink (machine_stm32)
  board/
    startup.s       # vectors + Reset_Handler
    linker.ld       # FLASH/RAM map
  Makefile          # emit → elf → bin → flash
  klin.mod
  README.md
```

Edit `main.kl`. Leave `board/` alone for a blink.

## How

```sh
klin get
make                         # arm-none-eabi-gcc → main.elf
make flash                   # dfu-util (chip must be in ROM DFU)
```

Needs `arm-none-eabi-gcc` on `PATH`. `make flash` needs `dfu-util`.
`make flash-swd` needs `st-flash`.

Arduino IDE “Upload” on this board is the same DFU path (STM32duino
calls `dfu-util` or CubeProgrammer). Klin stops at the ELF; the Makefile
only runs the tool you already have.

**DFU:** hold **BOOT0**, tap **NRST** (or plug USB-C while holding BOOT0),
then `make flash`.

**SWD:** ST-Link on SWDIO / SWCLK / GND / 3V3, then `make flash-swd`.

There is no hidden flasher in the compiler. No `klin flash`.

## Pins (WeAct F411CE)

| Piece | Pin |
|---|---|
| User LED (active low) | PC13 |
| User key | PA0 |
| HSE | 25 MHz (this blink uses HSI 16 MHz after reset) |
| USART1 TX/RX | PA9 / PA10 (USB-UART adapter — not USB CDC) |

## Links

- Chip API: [`machine_stm32`](https://github.com/klin-lang/machine_stm32) `@v0.5.0`
- Nucleo sibling: `klin init nucleo-f411` / [096](../../issues/096-board-nucleo-f411re.md)
- Walkthrough: [docs/embedded.md](../../docs/embedded.md)
