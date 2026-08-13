# Arduino boards and Klin

**Yes** — Klin can program many Arduino-class boards, but support is by **MCU
family**, not by Arduino IDE / Wiring. Klin emits **C**; you flash with the
usual toolchain for that chip (`avr-gcc`, ESP-IDF, pico-sdk, …).

Rule of thumb: find the **SoC** on the silkscreen / product page, then pick the
matching `machine_*` (or board pack). There is no single `arduino` package.

## Classic megaAVR (official + clones)

Package: [`machine_avr`](https://github.com/klin-lang/machine_avr) `@v0.2.0`  
Catalog: [061](../issues/061-micropython-machine-api.md)

| Board (examples) | Chip | Klin status |
|---|---|---|
| **Uno** / Uno clones / **Nano** / Pro Mini / many “328P” boards | ATmega328P | Pin…Adc + Pwm / Uart / I2c / Spi ✅ |
| **Mega** 2560 | ATmega2560 | Pin ✅; Pwm…Adc factories later |
| **Leonardo** / Micro / Pro Micro | ATmega32U4 | **Not yet** (USB AVR — later in `machine_avr` if needed) |
| **Nano Every** | ATmega4809 (megaAVR 0-series) | **Not yet** (different from 328P) |

Examples: `blink_uno` (D13 = PB5), `blink_mega` (D13 = PB7).

```sh
klin get github/klin-lang/machine_avr@v0.2.0
```

## Arduino boards that are not megaAVR

These keep the Arduino **name / form factor**, but need another package:

| Board (examples) | Chip | Klin path |
|---|---|---|
| **Nano ESP32** / ESP32 Dev Module–class | ESP32 / C3 / S3 | [`machine_esp`](https://github.com/klin-lang/machine_esp) ✅ (+ [`esp_wifi`](https://github.com/klin-lang/esp_wifi) / [`esp_eth`](https://github.com/klin-lang/esp_eth) / [`esp_ble`](https://github.com/klin-lang/esp_ble)) |
| **Nano RP2040 Connect** / Pico-class Arduino | RP2040 | [`machine_rp`](https://github.com/klin-lang/machine_rp) ✅ |
| Pico 2 / RP2350 Arduino-shaped | RP2350 | [`machine_rp`](https://github.com/klin-lang/machine_rp) ✅ (`*_rp2350`) |
| **Uno R4** Minima / WiFi | Renesas RA4M1 | **No** Klin `machine_*` yet |
| **Giga R1** WiFi | STM32H747 | No dedicated Arduino board pack; [`machine_stm32`](https://github.com/klin-lang/machine_stm32) is F411/F401-class today — **not** a drop-in Giga port |
| **Due** | SAM3X8E (Cortex-M3) | **No** |
| **MKR** / **Portenta** / Nicla / Opta | SAMD / STM32 / etc. | **No** dedicated packs yet |

Board packs Klin already has that are *Arduino-adjacent* (same chips, other brands):

- Waveshare ESP32-S3-Pico → [`waveshare_esp32_s3_pico`](https://github.com/klin-lang/waveshare_esp32_s3_pico) [100](../issues/100-board-waveshare-esp32-s3-pico.md)
- Adafruit RP2040 CAN Feather → [`adafruit_rp2040_can_feather`](https://github.com/klin-lang/adafruit_rp2040_can_feather) [098](../issues/098-board-adafruit-rp2040-can-feather.md)
- Nucleo-F411RE (STM32, not Arduino brand) → [`nucleo_f411re`](https://github.com/klin-lang/nucleo_f411re) [096](../issues/096-board-nucleo-f411re.md)

## Out of scope (for now)

- Arduino libraries (`.ino`, Wiring, `Servo.h`, …) as a Klin layer  
- ATmega2560 / 32U4 / 4809 full Pin…Adc parity with 328P  
- Uno R4 / Giga / Due / Portenta as first-class board packs  

## Links

- Targets overview: [062](../issues/062-targets-esp-rp.md)  
- `machine` catalog: [061](../issues/061-micropython-machine-api.md)  
- AVR: https://github.com/klin-lang/machine_avr  
- ESP: https://github.com/klin-lang/machine_esp  
- RP: https://github.com/klin-lang/machine_rp
