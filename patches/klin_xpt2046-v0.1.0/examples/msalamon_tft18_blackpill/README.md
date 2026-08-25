# msalamon 1.8″ TFT (ST7735S + XPT2046) + Black Pill F411CE

App example for the touch-capable 1.8″ module (e.g.
[msalamon TFT-00008](https://sklep.msalamon.pl/produkt/wyswietlacz-dotykowy-tft-lcd-1-8″-128x160px-rgb-spi-st7735s/))
on a WeAct-style
[STM32F411CEU6 Black Pill](https://sklep.msalamon.pl/produkt/stm32f411ceu6-dev-board/).

| Piece | Package |
|---|---|
| ST7735S LCD | [`klin_st7735`](https://github.com/klin-lang/klin_st7735) |
| XPT2046 touch | this seed (`klin_xpt2046`) |
| SPI SD slot on the module | later — [150](../../../issues/150-sd-spi-fatfs.md); keep `SD_CS` HIGH |
| Black Pill SDIO | chip peripheral only — **no** onboard slot; not this example |

Scaffold: `klin init weact-f411` ([147](../../../issues/147-board-weact-f411.md)).

## Wiring (SPI1 shared; separate CS)

Use **SPI1** (PA5/PA6/PA7). Idle **all** chip-selects HIGH when idle.

| Module | Black Pill F411CE |
|---|---|
| VCC | 3V3 |
| GND | GND |
| LED | 3V3 |
| SCK / CLK | PA5 (SPI1 SCK, AF5) |
| SDA / MOSI | PA7 (SPI1 MOSI, AF5) |
| MISO (LCD/SD/touch) | PA6 (SPI1 MISO, AF5) |
| A0 / DC | PB0 |
| RESET | PB1 |
| CS (LCD) | PB12 |
| SD_CS | PB15 — keep HIGH (no FatFs yet) |
| T_CS (touch) | PB10 |
| T_IRQ (optional) | PA8 — poll as `Pin` if wired; not required by the driver |

Some modules label touch pins `T_CLK` / `T_DIN` / `T_DO` / `T_CS` /
`T_IRQ`. If those share the LCD SPI bus, tie clocks/data to SPI1 and use
`T_CS` only as the chip-select above. If the silkscreen uses a dedicated
touch SPI, wire that bus instead and keep the same `Wire` shape.

## Klin files

| File | Role |
|---|---|
| `wire.kl` | SPI1 + CS adapters for LCD `Wire` and touch `Wire` |
| `hello_touch.kl` | fill LCD, poll touch, draw a pixel when pressed |

```sh
klin get github/klin-lang/machine_stm32@v0.5.0
klin get github/klin-lang/klin_st7735@v0.3.0
# from the Klin repo root (seed not published yet):
dart run bin/klin.dart --emit-c \
  -I patches/klin_xpt2046-v0.1.0 \
  patches/klin_xpt2046-v0.1.0/examples/msalamon_tft18_blackpill/hello_touch.kl
```

Linking an ELF needs `arm-none-eabi-gcc` + `klin init weact-f411` startup /
linker (copy or `@[link]`). Calibration (`touch.map`) is left to the app —
raw ADC → 128×160 after you measure corners.

## Flash

`klin` does not flash. Use the WeAct Makefile (`make flash` / DFU).
