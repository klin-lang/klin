# waveshare_esp32_s3_rlcd_42

Klin board pack for **Waveshare ESP32-S3-RLCD-4.2** — 4.2″ ST7305 reflective
LCD (400×300) + 18650 battery sense.

Panel protocol lives in [`klin_st7305`](https://github.com/klin-lang/klin_st7305)
(`Wire`). This pack owns the ESP-IDF SPI bus, pin map, and battery ADC.

Klin issue
[163](https://github.com/klin-lang/klin/blob/main/issues/163-board-waveshare-esp32-s3-rlcd-42.md) /
chip driver [164](https://github.com/klin-lang/klin/blob/main/issues/164-klin-st7305.md).

## Status (`@v0.3.0`)

| API | Notes |
|---|---|
| `init` | IDF SPI2 + `klin_st7305.attach` |
| `clear` / `fill_black` / `set_pixel` / `rect` / `flush` | Caller `[]u8` FB (**15000**) |
| `hline` / `vline` / `draw_rect` / `draw_text*` | via `klin_st7305@v0.2.0` |
| `width` / `height` / `fb_len` | 400 / 300 / 15000 |
| `lcd_*` / `key` / `boot` / `i2c_*` / `battery_gpio` | Pin map |
| `battery_adc_raw` / `battery_mv` | GPIO4 ADC1 CH3, ÷3 divider |

`version()` → `3`.

## Requirements

- Klin compiler
- [`klin_st7305@v0.2.0`](https://github.com/klin-lang/klin_st7305)
- ESP-IDF **v5.x** (`IDF_PATH`)

## Install

```sh
klin get github/klin-lang/klin_st7305@v0.2.0
klin get github/klin-lang/waveshare_esp32_s3_rlcd_42@v0.3.0
```

Or scaffold:

```sh
klin init waveshare-esp32-s3-rlcd-42 my_rlcd
```

## Usage

```klin
import "github/klin-lang/waveshare_esp32_s3_rlcd_42" board

@[cexport, codename("klin_app_main")]
fn app() {
  let mut e = board.init()
  if e != board.err_ok() {
    return
  }
  let mut fb: [15000]u8
  e = board.clear(fb[:])
  e = board.rect(fb[:], 20, 40, 380, 80, 0)
  e = board.flush(fb[:])
}
```

## Contract

- No Klin GC — framebuffer is yours (`[]u8`).
- White = bit 1 (`clear` → `0xFF`); black = bit 0.
- After inserting 18650, connect USB-C once to activate protection (Waveshare FAQ).

## Changelog

| Tag | Notes |
|---|---|
| `@v0.3.0` | Re-export font/UI from `klin_st7305@v0.2.0` |
| `@v0.2.1` | panel_s3 CMake uses `panel.link` / `bus_idf.c`; Wire data sets DC high |
| `@v0.2.0` | Panel via `klin_st7305`; board keeps SPI Wire + battery; FB API is `[]u8` |
| `@v0.1.0` | Monolithic `st7305_idf.c` (pins + panel + battery) |

## Links

- Klin issue: https://github.com/klin-lang/klin/blob/main/issues/163-board-waveshare-esp32-s3-rlcd-42.md
- Chip driver: https://github.com/klin-lang/klin_st7305
- Waveshare product: https://www.waveshare.com/esp32-s3-rlcd-4.2.htm
