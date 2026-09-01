# 163 — Board pack: Waveshare ESP32-S3-RLCD-4.2

**Status:** 🔨 published [`waveshare_esp32_s3_rlcd_42@v0.3.0`](https://github.com/klin-lang/waveshare_esp32_s3_rlcd_42/releases/tag/v0.3.0) (panel via [`klin_st7305@v0.2.0`](https://github.com/klin-lang/klin_st7305); first tag was `@v0.1.0`)  
**Depends on:** [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md), [099](099-machine-esp-esp32-s3.md), [075](075-board-pack-init-host.md), [164](164-klin-st7305.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **Allowlist only:** add `waveshare-esp32-s3-rlcd-42` to `klin init` ([075](075-board-pack-init-host.md)) |
| Where does the code live? | External: [`klin-lang/waveshare_esp32_s3_rlcd_42`](https://github.com/klin-lang/waveshare_esp32_s3_rlcd_42) `@v0.3.0` |
| Chip API | [`machine_esp`](https://github.com/klin-lang/machine_esp) (`*_s3`) |
| Display | **ST7305** via [`klin_st7305`](https://github.com/klin-lang/klin_st7305) (`Wire`); this pack owns ESP-IDF SPI + pins + battery |
| Separate `klin_st7305`? | ✅ [164](164-klin-st7305.md) — same pattern as [`klin_st7735`](https://github.com/klin-lang/klin_st7735) (not ST7789; that split is still later under [110](110-board-waveshare-pico-lcd-114.md)) |

## Why not fold into `waveshare_esp32_s3_pico`?

Different PCB, silk, and panel (RLCD + 18650 + audio/sensors). S3-Pico stays Pico-form-factor blink/WS2812 ([100](100-board-waveshare-esp32-s3-pico.md)).

## Scope (`@v0.3.0`)

- `pins.kl` — display SPI (SCK=11, MOSI=12, DC=5, CS=40, RST=41), KEY=18, BOOT=0, I2C SDA/SCL=13/14, battery ADC GPIO4
- `bus_idf.c` — ESP-IDF SPI2 + GPIO Wire hooks + battery ADC
- `st7305.kl` — thin board surface over `klin_st7305` (`attach` / `clear` / `rect` / `flush` / `draw_text*` on caller `[]u8`)
- Smoke: `examples/smoke/` (`--emit-c`)
- Hardware: `examples/panel_s3/` (clear → fill bar → flush)

**Scaffold:** `klin init waveshare-esp32-s3-rlcd-42` — ESP-IDF panel clear/flush via
`templates/waveshare-esp32-s3-rlcd-42/` ([075](075-board-pack-init-host.md)).

### Later (not this tag)

- SHTC3 / PCF85063 / TF card
- Audio ES8311 + ES7210
- Wi‑Fi / BLE / espnow (use [`esp_wifi`](https://github.com/klin-lang/esp_wifi) / [`espnow`](https://github.com/klin-lang/espnow) separately)

## Out of scope

- Folding into `machine_esp` or S3-Pico pack
- Freestanding (no IDF)
- Hidden framebuffer allocation (caller owns the 15 KB buffer)

## Contract (prime rule)

- No Klin GC / hidden heap — framebuffer is a **caller** `[15000]u8` / `[]u8`.
- White = bit **1** (buffer cleared to `0xFF`); black = bit **0**.
- Panel geometry for RAM: **400×300** landscape (Waveshare CASET/RASET).
- 18650: after inserting the cell, connect USB-C once to wake the protection circuit (Waveshare FAQ).
- SPI / ADC / delays are **IDF contracts** (board `Wire`); panel bytes are **`klin_st7305`**.

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

Mirrors: [`patches/waveshare_esp32_s3_rlcd_42-v0.3.0/`](../patches/waveshare_esp32_s3_rlcd_42-v0.3.0/),
[`patches/klin_st7305-v0.1.0/`](../patches/klin_st7305-v0.1.0/).

## Links

- Pack: https://github.com/klin-lang/waveshare_esp32_s3_rlcd_42
- Tag: [v0.2.0](https://github.com/klin-lang/waveshare_esp32_s3_rlcd_42/releases/tag/v0.3.0)
- Chip driver: [164](164-klin-st7305.md) / https://github.com/klin-lang/klin_st7305
- Waveshare product: https://www.waveshare.com/esp32-s3-rlcd-4.2.htm
- Waveshare docs: https://docs.waveshare.com/ESP32-S3-RLCD-4.2
- Waveshare demo repo: https://github.com/waveshareteam/ESP32-S3-RLCD-4.2
- Chip: https://github.com/klin-lang/machine_esp
- Sibling S3 Pico: [100](100-board-waveshare-esp32-s3-pico.md)
- `klin init`: [075](075-board-pack-init-host.md)
