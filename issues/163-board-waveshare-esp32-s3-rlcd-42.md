# 163 — Board pack: Waveshare ESP32-S3-RLCD-4.2

**Status:** 🔨 published [`waveshare_esp32_s3_rlcd_42@v0.1.0`](https://github.com/klin-lang/waveshare_esp32_s3_rlcd_42/releases/tag/v0.1.0)  
**Depends on:** [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md), [099](099-machine-esp-esp32-s3.md), [075](075-board-pack-init-host.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **Allowlist only:** add `waveshare-esp32-s3-rlcd-42` to `klin init` ([075](075-board-pack-init-host.md)) |
| Where does the code live? | External: [`klin-lang/waveshare_esp32_s3_rlcd_42`](https://github.com/klin-lang/waveshare_esp32_s3_rlcd_42) `@v0.1.0` |
| Chip API | [`machine_esp`](https://github.com/klin-lang/machine_esp) (`*_s3`) |
| Display | **ST7305** RLCD 400×300 monochrome — in this board pack (not `machine_esp`) |
| Separate `klin_st7305`? | **Later** — same split as [110](110-board-waveshare-pico-lcd-114.md) vs generic ST7789 |

## Why not fold into `waveshare_esp32_s3_pico`?

Different PCB, silk, and panel (RLCD + 18650 + audio/sensors). S3-Pico stays Pico-form-factor blink/WS2812 ([100](100-board-waveshare-esp32-s3-pico.md)).

## Scope (`@v0.1.0`)

- `pins.kl` — display SPI (SCK=11, MOSI=12, DC=5, CS=40, RST=41), KEY=18, BOOT=0, I2C SDA/SCL=13/14, battery ADC GPIO4
- `st7305.kl` + `st7305_idf.c` — SPI bring-up, Waveshare init sequence, caller framebuffer (**15 000** bytes), `clear` / `fill` / `set_pixel` / `rect` / `flush`
- `battery_adc_raw` / `battery_mv` — GPIO4 oneshot ADC, ×3 divider (documented)
- Smoke: `examples/smoke/` (`--emit-c`, stubs)
- Hardware: `examples/panel_s3/` (clear → fill bar → flush)

**Scaffold:** `klin init waveshare-esp32-s3-rlcd-42` — ESP-IDF panel clear/flush via
`templates/waveshare-esp32-s3-rlcd-42/` ([075](075-board-pack-init-host.md)).

### Later (not this tag)

- `klin_st7305` MCU-agnostic Wire driver
- SHTC3 / PCF85063 / TF card
- Audio ES8311 + ES7210
- Font / UI helpers beyond `set_pixel` / `rect`
- Wi‑Fi / BLE / espnow (use [`esp_wifi`](https://github.com/klin-lang/esp_wifi) / [`espnow`](https://github.com/klin-lang/espnow) separately)

## Out of scope

- Folding into `machine_esp` or S3-Pico pack
- Freestanding (no IDF)
- Hidden framebuffer allocation (caller owns the 15 KB buffer)

## Contract (prime rule)

- No Klin GC / hidden heap — framebuffer is a **caller** `[15000]u8` (or pointer + len).
- White = bit **1** (buffer cleared to `0xFF`); black = bit **0**.
- Panel geometry for RAM: **400×300** landscape (Waveshare CASET/RASET).
- 18650: after inserting the cell, connect USB-C once to wake the protection circuit (Waveshare FAQ).
- SPI / ADC / delays are **IDF contracts**.

## Pin map (MVP)

| Function | GPIO |
|---|---|
| SPI SCK / MOSI | 11 / 12 |
| DC / CS / RST | 5 / 40 / 41 |
| KEY / BOOT | 18 / 0 |
| I2C SDA / SCL | 13 / 14 |
| Battery ADC | 4 (÷3) |

## Usage

```sh
klin init waveshare-esp32-s3-rlcd-42 my_rlcd
cd my_rlcd
. $IDF_PATH/export.sh
klin get
make emit KLIN=/path/to/klin/bin/klin.dart
make build
make flash
```

```klin
import "github/klin-lang/waveshare_esp32_s3_rlcd_42" board
```

Mirror: [`patches/waveshare_esp32_s3_rlcd_42-v0.1.0/`](../patches/waveshare_esp32_s3_rlcd_42-v0.1.0/).

## Links

- Pack: https://github.com/klin-lang/waveshare_esp32_s3_rlcd_42
- Tag: [v0.1.0](https://github.com/klin-lang/waveshare_esp32_s3_rlcd_42/releases/tag/v0.1.0)
- Waveshare product: https://www.waveshare.com/esp32-s3-rlcd-4.2.htm
- Waveshare docs: https://docs.waveshare.com/ESP32-S3-RLCD-4.2
- Waveshare demo repo: https://github.com/waveshareteam/ESP32-S3-RLCD-4.2
- Chip: https://github.com/klin-lang/machine_esp
- Sibling S3 Pico: [100](100-board-waveshare-esp32-s3-pico.md)
- `klin init`: [075](075-board-pack-init-host.md)
