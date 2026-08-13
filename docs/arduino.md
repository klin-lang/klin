# Arduino boards and Klin

**Yes** — Klin can program many Arduino-class boards, but support is by **MCU
family**, not by Arduino IDE / Wiring. Klin emits **C**; you flash with the
usual toolchain for that chip (`avr-gcc`, ESP-IDF, pico-sdk, …).

Rule of thumb: find the **SoC** on the silkscreen / product page, then pick the
matching `machine_*` (or board pack). There is no single `arduino` package.

Backlog for boards not yet supported: [107](../issues/107-later-tracks-arduino-boards.md).

## Classic megaAVR (official + clones)

Package: [`machine_avr`](https://github.com/klin-lang/machine_avr) `@v0.2.0`  
Catalog: [061](../issues/061-micropython-machine-api.md)

| Board (examples) | Chip | Klin status |
|---|---|---|
| **Uno** / Uno clones / **Nano** / Pro Mini / many “328P” boards | ATmega328P | Pin…Adc + Pwm / Uart / I2c / Spi ✅ |
| **Mega** 2560 | ATmega2560 | Pin ✅; Pwm…Adc factories later |
| **Leonardo** / Micro / Pro Micro | ATmega32U4 | Later → [107](../issues/107-later-tracks-arduino-boards.md) (extend `machine_avr`) |
| **Nano Every** | ATmega4809 | Later (not 328P) |

Examples: `blink_uno` (D13 = PB5), `blink_mega` (D13 = PB7).

```sh
klin get github/klin-lang/machine_avr@v0.2.0
```

## Arduino boards that are not megaAVR

| Board (examples) | Chip | Klin path |
|---|---|---|
| **Nano ESP32** / ESP32 Dev Module–class | ESP32 / C3 / S3 | [`machine_esp`](https://github.com/klin-lang/machine_esp) ✅ (+ wifi / eth / ble) |
| **Nano RP2040 Connect** / Pico-class Arduino | RP2040 / RP2350 | [`machine_rp`](https://github.com/klin-lang/machine_rp) ✅ |
| **Uno R4** Minima / WiFi | Renesas RA4M1 (+ ESP32-S3 on WiFi) | Later → [107](../issues/107-later-tracks-arduino-boards.md) (new RA port) |
| **Giga R1** WiFi | STM32H747 (+ Murata 1DX) | Later → [107](../issues/107-later-tracks-arduino-boards.md) (H7 ≠ F411) |
| **Due** | SAM3X8E (Cortex-M3) | Later → [107](../issues/107-later-tracks-arduino-boards.md) |
| **Portenta** H7 / C33 | STM32H747 / RA6M5 (+ radio) | Later → [107](../issues/107-later-tracks-arduino-boards.md) |

## Out of scope (for now)

- Arduino libraries (`.ino`, Wiring, `Servo.h`, …) as a Klin layer  
- Full Pin…Adc on every Arduino SKU day one — see queue in [107](../issues/107-later-tracks-arduino-boards.md)

## Links

- Later Arduino tracks: [107](../issues/107-later-tracks-arduino-boards.md)  
- Targets overview: [062](../issues/062-targets-esp-rp.md)  
- `machine` catalog: [061](../issues/061-micropython-machine-api.md)  
- AVR: https://github.com/klin-lang/machine_avr  
- ESP: https://github.com/klin-lang/machine_esp  
- RP: https://github.com/klin-lang/machine_rp
