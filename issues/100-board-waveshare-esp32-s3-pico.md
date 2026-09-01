# 100 — Board pack: Waveshare ESP32-S3-Pico

**Status:** ✅ published `@v0.3.0`  
**Depends on:** [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md), [099](099-machine-esp-esp32-s3.md), [075](075-board-pack-init-host.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | External: [`klin-lang/waveshare_esp32_s3_pico`](https://github.com/klin-lang/waveshare_esp32_s3_pico) `@v0.3.0` |
| Chip API | [`machine_esp`](https://github.com/klin-lang/machine_esp) `@v0.7.0` (`*_s3` + `rmt_tx_s3`) |
| Board extras | Pico silkscreen→GPIO map + WS2812 **RMT** helper + IDF bus examples |

## Scope (`@v0.3.0`)

- `pins.kl` — `d0`…`d28`, `a1`…`a3`, `rgb` (GPIO21), `usb_adc`, UART/I2C/SPI helpers, `spi_cs`, `a*_adc_ch`, `peri_hz` / `xtal_hz`
- `rgb.kl` — `rgb_out` / `write` via **RMT TX** (wire **RGB** per Waveshare FAQ); bit-bang escape `rgb_write_bb`
- Examples (`idf.py set-target esp32s3`):
  - `blink` — D10→GPIO35
  - `rgb` — onboard WS2812 (RMT)
  - `uart` — D0/D1 UART0 TX/RX
  - `i2c` — D6/D7 I2C0 + D10 blink
  - `spi` — D10/D11/D12 SPI2 + soft CS D13
  - `adc` — A1 (CH6) → PWM D10
  - `pwm` — D10 LEDC fade

**Out of scope:** BLE, freestanding (no IDF), camera / USB OTG (→ [109](109-esp-camera-idf.md) / [108](108-esp-usb-idf.md)).
Pico LCD shields use Pico GP map — [`waveshare_pico_lcd_114`](https://github.com/klin-lang/waveshare_pico_lcd_114) [110](110-board-waveshare-pico-lcd-114.md) (`machine_rp` path; S3 SPI twin later).
Chip Wi‑Fi (silicon radio) → separate [`esp_wifi`](https://github.com/klin-lang/esp_wifi)
([101](101-esp-wifi-idf.md)); this pack has **no** radio API.

**Scaffold:** `klin init waveshare-esp32-s3-pico` — ESP-IDF blink (D10) via
bundled `templates/waveshare-esp32-s3-pico/` ([075](075-board-pack-init-host.md)).

Sibling RLCD board (ST7305 + 18650): [163](163-board-waveshare-esp32-s3-rlcd-42.md) /
[`waveshare_esp32_s3_rlcd_42`](https://github.com/klin-lang/waveshare_esp32_s3_rlcd_42).

## Usage

```klin
import "github/klin-lang/machine_esp" machine
import "github/klin-lang/waveshare_esp32_s3_pico" board

@[cexport, codename("klin_app_main")]
fn app() {
  let neo = board.rgb_out()
  neo.write(32, 0, 0)
}
```

```sh
klin get github/klin-lang/waveshare_esp32_s3_pico@v0.3.0
klin get github/klin-lang/machine_esp@v0.7.0
```

## Links

- Repo: https://github.com/klin-lang/waveshare_esp32_s3_pico  
- Tag: [v0.3.0](https://github.com/klin-lang/waveshare_esp32_s3_pico/releases/tag/v0.3.0)  
- Wiki: [Waveshare ESP32-S3-Pico](https://www.waveshare.com/wiki/ESP32-S3-Pico)  
- Shop (PL): [Botland 23396 — ESP32-S3-Pico](https://botland.com.pl/moduly-wifi-i-bt-esp32/23396-esp32-s3-pico-plytka-rozwojowa-zgodna-z-raspberry-pi-pico-waveshare-23803.html)  

- Chip port: [099](099-machine-esp-esp32-s3.md)  
- Sibling packs: [095](095-board-waveshare-rp2350-lcd-096.md), [098](098-board-adafruit-rp2040-can-feather.md), [110](110-board-waveshare-pico-lcd-114.md)
