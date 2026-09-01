# waveshare_esp32_s3_rlcd_42

Klin board pack for **Waveshare ESP32-S3-RLCD-4.2** — 4.2″ ST7305 reflective
LCD (400×300) + 18650 battery sense.

Not Arduino. Not `machine_esp` MMIO. Chip Pin…Adc stays in
[`machine_esp`](https://github.com/klin-lang/machine_esp). This pack owns the
panel SPI/init and board pin map. Klin issue
[163](https://github.com/klin-lang/klin/blob/main/issues/163-board-waveshare-esp32-s3-rlcd-42.md).

## Status (`@v0.1.0`)

| API | Notes |
|---|---|
| `init` | SPI2 + Waveshare ST7305 sequence |
| `clear` / `fill_black` / `set_pixel` / `rect` / `flush` | Caller FB **15000** bytes |
| `width` / `height` / `fb_len` | 400 / 300 / 15000 |
| `lcd_*` / `key` / `boot` / `i2c_*` / `battery_gpio` | Pin map |
| `battery_adc_raw` / `battery_mv` | GPIO4 ADC1 CH3, ÷3 divider |

`version()` → `1`.

## Requirements

- Klin compiler
- ESP-IDF **v5.x** (`IDF_PATH`)
- Octal PSRAM 80 MHz recommended (`sdkconfig.defaults` in examples)

## Install

```sh
klin get github/klin-lang/waveshare_esp32_s3_rlcd_42@v0.1.0
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
  e = board.clear(cast(*mut u8, &fb[0]), 15000)
  e = board.rect(cast(*mut u8, &fb[0]), 15000, 20, 40, 380, 80, 0)
  e = board.flush(cast(*u8, &fb[0]), 15000)
}
```

## Contract

- No Klin GC — framebuffer is yours.
- White = bit 1 (`clear` → `0xFF`); black = bit 0.
- After inserting 18650, connect USB-C once to activate protection (Waveshare FAQ).
- Audio / SHTC3 / RTC / Wi‑Fi: out of this tag.

## Links

- Klin issue: https://github.com/klin-lang/klin/blob/main/issues/163-board-waveshare-esp32-s3-rlcd-42.md
- Waveshare product: https://www.waveshare.com/esp32-s3-rlcd-4.2.htm
- Waveshare docs: https://docs.waveshare.com/ESP32-S3-RLCD-4.2
- Waveshare demos: https://github.com/waveshareteam/ESP32-S3-RLCD-4.2
- Chip: https://github.com/klin-lang/machine_esp

## Changelog

| Tag | Notes |
|---|---|
| `@v0.1.0` | pins + ST7305 clear/fill/pixel/rect/flush + battery ADC |
