# waveshare_esp32_s3_rlcd_42

Klin board pack for **Waveshare ESP32-S3-RLCD-4.2** — 4.2″ ST7305 reflective
LCD (400×300) + 18650 battery sense.

Panel protocol lives in [`klin_st7305`](https://github.com/klin-lang/klin_st7305)
(`Wire`). Sensors: [`klin_shtc3`](https://github.com/klin-lang/klin_shtc3) /
[`klin_pcf85063`](https://github.com/klin-lang/klin_pcf85063). This pack owns
the ESP-IDF SPI bus, I2C master, pin map, TF SDMMC, battery ADC, audio I2S +
codec bring-up, and thin sensor glue.

**Wi‑Fi / BLE / ESP-NOW** are on the ESP32-S3 silicon — use separate packs
([`esp_wifi`](https://github.com/klin-lang/esp_wifi) /
[`esp_ble`](https://github.com/klin-lang/esp_ble) /
[`espnow`](https://github.com/klin-lang/espnow)); not this board API.

Klin issue
[163](https://github.com/klin-lang/klin/blob/main/issues/163-board-waveshare-esp32-s3-rlcd-42.md) /
chip driver [164](https://github.com/klin-lang/klin/blob/main/issues/164-klin-st7305.md).

## Status (`@v0.8.0`)

| API | Notes |
|---|---|
| `init` | IDF SPI2 + `klin_st7305.attach` |
| `clear` / `fill_black` / `set_pixel` / `rect` / `flush` | Caller `[]u8` FB (**15000**) |
| `hline` / `vline` / `draw_rect` / `draw_text*` | via `klin_st7305@v0.2.0` |
| `width` / `height` / `fb_len` | 400 / 300 / 15000 |
| `lcd_*` / `key` / `boot` / `i2c_sda` / `i2c_scl` / `battery_gpio` | Pin map |
| `battery_adc_raw` / `battery_mv` | GPIO4 ADC1 CH3, ÷3 divider |
| `tf_clk` / `tf_cmd` / `tf_d0` | SDMMC 1-bit: 38 / 21 / 39 |
| `tf_mount` / `tf_unmount` / `tf_ready` / `tf_write` / `tf_read` | IDF SDMMC + VFS Fat at `/sdcard` |
| `i2c_init` / `i2c_deinit` / `i2c_ready` / `i2c_probe` | IDF `i2c_master`, SDA=13 SCL=14 @ 100 kHz |
| `i2c_write` / `i2c_read` / `i2c_write_read` | Caller buffers; 7-bit addr |
| `shtc3_measure(temp_mC, hum_mRh)` | I2C init + `klin_shtc3` measure |
| `rtc_read` / `rtc_set` | I2C init + `klin_pcf85063` datetime |
| `audio_mclk` / `bclk` / `ws` / `dout` / `din` / `pa` | I2S 16/9/45/8/10 + PA 46 |
| `audio_init` / `deinit` / `ready` / `pa_enable` / `set_volume` | ES8311 + ES7210 |
| `audio_write` / `audio_read` | Caller PCM (`[]u8`); 16-bit stereo |

`version()` → `8`.

## Requirements

- Klin compiler
- [`klin_st7305@v0.2.0`](https://github.com/klin-lang/klin_st7305)
- [`klin_shtc3@v0.1.0`](https://github.com/klin-lang/klin_shtc3)
- [`klin_pcf85063@v0.1.0`](https://github.com/klin-lang/klin_pcf85063)
- ESP-IDF **v5.x** (`IDF_PATH`)

## Install

```sh
klin get github/klin-lang/klin_st7305@v0.2.0
klin get github/klin-lang/klin_shtc3@v0.1.0
klin get github/klin-lang/klin_pcf85063@v0.1.0
klin get github/klin-lang/waveshare_esp32_s3_rlcd_42@v0.8.0
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

Sensors (I2C SDA=13 SCL=14):

```klin
let mut t: i32 = 0
let mut h: i32 = 0
let e = board.shtc3_measure(&t, &h)
let _ = board.rtc_set(0, 0, 12, 1, 1, 9, 26)
```

Audio (I2S + ES8311/ES7210; rates 16000 / 24000 / 48000):

```klin
let e = board.audio_init(16000)
let _ = board.audio_set_volume(70)
let mut pcm: [256]u8
let _w = board.audio_write(cast(*u8, &pcm[0]), 256)
let n = board.audio_read(cast(*mut u8, &pcm[0]), 256)
```

### Radio (silicon — separate packs)

No board pins / no board `wifi_*` API. Same binary can import board + radio:

```sh
klin get github/klin-lang/esp_wifi@v0.4.0
klin get github/klin-lang/esp_ble@v0.10.0
klin get github/klin-lang/espnow@v0.1.0
```

```klin
import "github/klin-lang/esp_wifi" wifi
import "github/klin-lang/esp_ble" ble
import "github/klin-lang/espnow" now
```

| Pack | Role |
|---|---|
| [`esp_wifi`](https://github.com/klin-lang/esp_wifi) `@v0.4.0` | STA / SoftAP / scan / link |
| [`esp_ble`](https://github.com/klin-lang/esp_ble) `@v0.10.0` | NimBLE GAP/GATT + Mesh OnOff |
| [`espnow`](https://github.com/klin-lang/espnow) `@v0.1.0` | ESP-NOW peer/broadcast (no IP) |

TF slot is **SDMMC**, not SPI — use this pack's `tf_*`, not [`klin_sd_spi`](https://github.com/klin-lang/klin_sd_spi).

## Contract

- No Klin GC — framebuffer, I2C, and PCM buffers are yours (`[]u8`).
- White = bit 1 (`clear` → `0xFF`); black = bit 0.
- After inserting 18650, connect USB-C once to activate protection (Waveshare FAQ).
- `audio_init` turns the PA on; call `audio_pa_enable(0)` to mute the amp.
- Radio stacks are **IDF contracts** in their own packages — not folded into this board.

## Changelog

| Tag | Notes |
|---|---|
| `@v0.8.0` | Document silicon radio via `esp_wifi` / `esp_ble` / `espnow` (no board radio API) |
| `@v0.7.0` | Audio: I2S duplex + ES8311 DAC + ES7210 ADC + PA (`audio_*`) |
| `@v0.6.0` | SHTC3 + PCF85063 board glue (`shtc3_measure`, `rtc_read` / `rtc_set`) |
| `@v0.5.0` | I2C master helper (SDA=13 SCL=14): init/probe/write/read/write_read |
| `@v0.4.0` | TF SDMMC (CLK=38 CMD=21 D0=39) mount/read/write |
| `@v0.3.0` | Re-export font/UI from `klin_st7305@v0.2.0` |
| `@v0.2.1` | panel_s3 CMake uses `panel.link` / `bus_idf.c`; Wire data sets DC high |
| `@v0.2.0` | Panel via `klin_st7305`; board keeps SPI Wire + battery; FB API is `[]u8` |
| `@v0.1.0` | Monolithic `st7305_idf.c` (pins + panel + battery) |

## Links

- Klin issue: https://github.com/klin-lang/klin/blob/main/issues/163-board-waveshare-esp32-s3-rlcd-42.md
- Chip driver: https://github.com/klin-lang/klin_st7305
- SHTC3: https://github.com/klin-lang/klin_shtc3
- RTC: https://github.com/klin-lang/klin_pcf85063
- Wi‑Fi: https://github.com/klin-lang/esp_wifi
- BLE: https://github.com/klin-lang/esp_ble
- ESP-NOW: https://github.com/klin-lang/espnow
- Waveshare product: https://www.waveshare.com/esp32-s3-rlcd-4.2.htm
