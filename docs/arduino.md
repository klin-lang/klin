# Arduino boards and Klin

**Yes** — Klin can program many Arduino-class boards, but support is by **MCU
family**, not by Arduino IDE / Wiring. Klin emits **C**; you flash with the
usual toolchain for that chip (`avr-gcc`, ESP-IDF, pico-sdk, …).

Rule of thumb: find the **SoC** on the silkscreen / product page, then pick the
matching `machine_*` (or board pack). There is no single `arduino` package.
Bundled `klin init` boards (Pico, Nucleo, ESP32-S3, …):
[embedded.md](embedded.md).

Backlog for boards not yet supported: [107](../issues/107-later-tracks-arduino-boards.md).

## Classic megaAVR (official + clones)

Package: [`machine_avr`](https://github.com/klin-lang/machine_avr) `@v0.2.0`  
Catalog: [061](../issues/061-micropython-machine-api.md)

| Board (examples) | Chip | Klin status |
|---|---|---|
| **Uno** / Uno clones / **Nano** / Pro Mini / many “328P” boards | ATmega328P | Pin…Adc + Pwm / Uart / I2c / Spi ✅ |
| **Mega** 2560 | ATmega2560 | Pin ✅; Pwm…Adc factories later |
| **Leonardo** / Micro / Pro Micro | ATmega32U4 | ✅ [`machine_avr@v0.3.0`](https://github.com/klin-lang/machine_avr/releases/tag/v0.3.0) — [142](../issues/142-machine-avr-atmega32u4.md) (`pin_out_32u4` …; D13 = **PC7**) |
| **Nano Every** | ATmega4809 (megaAVR 0-series) | Later (not 328P) |

Examples: `blink_uno` (D13 = PB5), `blink_mega` (D13 = PB7).

```sh
klin get github/klin-lang/machine_avr@v0.2.0
```

## tinyAVR (not classic megaAVR)

Modern **tinyAVR 0/1/2-series** (AVRxt + UPDI) is a **separate** package —
[`machine_tinyavr`](https://github.com/klin-lang/machine_tinyavr) — planned as
[141](../issues/141-machine-tinyavr.md) (MVP **ATtiny1624**). Do not use
`machine_avr` for these parts. Classic ATtiny85 is out of that MVP.

## Arduino boards that are not megaAVR

These keep the Arduino **name / form factor**, but need another package:

| Board (examples) | Chip | Klin path |
|---|---|---|
| **Nano ESP32** / S3– or C3–class modules | ESP32-C3 / ESP32-S3 | [`machine_esp`](https://github.com/klin-lang/machine_esp) ✅ (+ [`esp_wifi`](https://github.com/klin-lang/esp_wifi) / [`esp_eth`](https://github.com/klin-lang/esp_eth) / [`esp_ble`](https://github.com/klin-lang/esp_ble) / [`espnow`](https://github.com/klin-lang/espnow) seed [159](../issues/159-esp-now-idf.md)). Classic ESP32 (Xtensa dual) still later ([062](../issues/062-targets-esp-rp.md)). |
| **Nano RP2040 Connect** / Pico-class Arduino | RP2040 | [`machine_rp`](https://github.com/klin-lang/machine_rp) ✅ |
| Pico 2 / RP2350 Arduino-shaped | RP2350 | [`machine_rp`](https://github.com/klin-lang/machine_rp) ✅ (`*_rp2350`) |
| **Uno R4** Minima / WiFi | Renesas RA4M1 (+ ESP32-S3 on WiFi) | Later → [107](../issues/107-later-tracks-arduino-boards.md) (new RA port) |
| **Giga R1** WiFi | STM32H747 (+ Murata 1DX) | Later → [107](../issues/107-later-tracks-arduino-boards.md) (H7 ≠ F411) |
| **Due** | SAM3X8E (Cortex-M3) | Later → [107](../issues/107-later-tracks-arduino-boards.md) |
| **Portenta** H7 / C33 | STM32H747 / RA6M5 (+ radio) | Later → [107](../issues/107-later-tracks-arduino-boards.md) |
| **MKR** / Nicla / Opta | SAMD / STM32 / etc. | Later (open a row in [107](../issues/107-later-tracks-arduino-boards.md) when needed) |

Board packs Klin already has that are *Arduino-adjacent* (same chips, other brands):

- Waveshare ESP32-S3-Pico → [`waveshare_esp32_s3_pico`](https://github.com/klin-lang/waveshare_esp32_s3_pico) [100](../issues/100-board-waveshare-esp32-s3-pico.md)
- Waveshare ESP32-S3-RLCD-4.2 → [`waveshare_esp32_s3_rlcd_42`](https://github.com/klin-lang/waveshare_esp32_s3_rlcd_42) + [`klin_st7305`](https://github.com/klin-lang/klin_st7305) [163](../issues/163-board-waveshare-esp32-s3-rlcd-42.md) / [164](../issues/164-klin-st7305.md)
- Adafruit RP2040 CAN Feather → [`adafruit_rp2040_can_feather`](https://github.com/klin-lang/adafruit_rp2040_can_feather) [098](../issues/098-board-adafruit-rp2040-can-feather.md)
- Nucleo-F411RE (STM32, not Arduino brand) → [`nucleo_f411re`](https://github.com/klin-lang/nucleo_f411re) [096](../issues/096-board-nucleo-f411re.md)
- WeAct Black Pill F411CE → `klin init weact-f411` (`make flash` = `dfu-util`, same tool STM32duino uses) [147](../issues/147-board-weact-f411.md)

## Out of scope (for now)

- Arduino libraries (`.ino`, Wiring, `Servo.h`, …) as a Klin layer  
- Full Pin…Adc on every Arduino SKU day one — see queue in [107](../issues/107-later-tracks-arduino-boards.md)  
- ATmega2560 / 32U4 / 4809 full Pin…Adc parity with 328P  

## Links

- Later Arduino tracks: [107](../issues/107-later-tracks-arduino-boards.md)  
- Leonardo / 32U4: [142](../issues/142-machine-avr-atmega32u4.md)  
- tinyAVR: [141](../issues/141-machine-tinyavr.md)  
- Targets overview: [062](../issues/062-targets-esp-rp.md)  
- `machine` catalog: [061](../issues/061-micropython-machine-api.md)  
- AVR: https://github.com/klin-lang/machine_avr  
- ESP: https://github.com/klin-lang/machine_esp  
- RP: https://github.com/klin-lang/machine_rp
