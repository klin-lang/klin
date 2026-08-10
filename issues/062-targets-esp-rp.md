# 062 — MCU targets beyond STM32: ESP32, RP2040, RP2350, STM8, CH32V, GD32V

**Status:** 🚧 — RP / ESP / STM8 / CH32V / GD32V via external `machine_*` (Pin…Adc); Wi‑Fi / freestanding ESP / SDCC link open
**Depends on:** [010](010-bare-metal.md); nice to have [022](022-asm-libraries.md), [027](027-svd-ergonomic-api.md), [031](031-hal-libraries.md), [053](053-device-board-assets.md), [054](054-embedded-project-layout.md)

## Context (conversation notes)

Klin emits **C** — frontend is not “STM32 only”. Today the ready
bare-metal path is mainly **STM32 Cortex-M** (`examples/stm32/…`). Question: can we
target **ESP32**, **RP2040**, **RP2350**, **STM8**, **CH32V**, **GD32V**?

## Short verdict

| Target | Realistic? | Notes |
|---|---|---|
| **RP2040** | ✅ path exists | [`machine_rp`](https://github.com/klin-lang/machine_rp) `@v0.6.0` — Pin+Pwm+Rc+Uart+I2c+Spi+Adc (no DAC). |
| **RP2350** | ✅ Arm + RISC-V | Same APIs via `*_rp2350` twins. Board: Waveshare LCD-0.96 → [095](095-board-waveshare-rp2350-lcd-096.md). |
| **ESP32-C3** | ✅ Pin…Adc | [`machine_esp`](https://github.com/klin-lang/machine_esp) `@v0.4.0` — MMIO + LEDC; minimal **ESP-IDF** boot; no DAC; no Wi‑Fi in MVP. |
| **STM8S** | ✅ Pin…Adc (emit-c) | [`machine_stm8`](https://github.com/klin-lang/machine_stm8) `@v0.2.0` — no DAC; SDCC link later. |
| **CH32V003** | ✅ Pin…Adc | [`machine_ch32v`](https://github.com/klin-lang/machine_ch32v) `@v0.1.0` — QingKe RV32EC ([086](086-machine-ch32v.md)). |
| **GD32VF103** | ✅ Pin…Adc | [`machine_gd32v`](https://github.com/klin-lang/machine_gd32v) `@v0.2.0` — Nuclei N205 ([087](087-machine-gd32v.md)). |
| **ESP32** (classic / other) | Later | Classic = **Xtensa**; C6/S3 etc. separate from C3 MVP. |

## What already carries to these MCUs

- single `.c` emit, checker, `#line`
- `@[codename]` / ISR, `@[cimport]` / `@[link]` (C and ASM)
- SVD → typed registers ([011](011-svd.md) / [027](027-svd-ergonomic-api.md)), when chip SVD exists
- rule: startup / vector table / clock stay explicit (not language magic)

## What is not out of the box

- generic board pack / Klin-tree `examples/rp2040/…` (lives in [`machine_rp`](https://github.com/klin-lang/machine_rp); Waveshare RP2350-LCD-0.96 → [`waveshare_rp2350_lcd_096`](https://github.com/klin-lang/waveshare_rp2350_lcd_096) [095](095-board-waveshare-rp2350-lcd-096.md))
- automatic ESP-IDF or pico-sdk in Klin CLI (example ships its own `idf.py` flow)
- freestanding ESP image (no IDF)
- Classic Xtensa ESP32 / C6 / S3 ports
- hardware DAC on RP / ESP-C3 / STM8S / F411

## Order sketch

1. **RP2040** blink + `machine` Pin — ✅  
2. **RP2350** Arm / RISC-V blink — ✅  
3. **ESP32-C3** Pin + blink — ✅  
4. **Pwm** / **Rc** on RP + ESP — ✅  
5. **Uart** / **I2c** / **Spi** / **Adc** on RP + ESP + STM8 — ✅ (`machine_rp@v0.6.0`, `machine_esp@v0.4.0`, `machine_stm8@v0.2.0`)  
6. **CH32V003** Pin…Adc — ✅ (`machine_ch32v@v0.1.0`; [086](086-machine-ch32v.md))  
7. **GD32VF103** Pin…Adc — ✅ (`machine_gd32v@v0.2.0`; [087](087-machine-gd32v.md))  
8. Wi‑Fi / freestanding ESP / SDCC STM8 — later  

## Out of scope

- implementation in this issue (placeholder / decision only)
- promise of full portability like µPython between ports
- priority relative to language core / current STM32 path

## Links

- RP package: https://github.com/klin-lang/machine_rp  
- ESP package: https://github.com/klin-lang/machine_esp  
- STM8 package: https://github.com/klin-lang/machine_stm8  
- CH32V package: https://github.com/klin-lang/machine_ch32v ([086](086-machine-ch32v.md))  
- GD32V package: https://github.com/klin-lang/machine_gd32v ([087](087-machine-gd32v.md))  
- Bare-metal STM32: [010](010-bare-metal.md)  
- Project layout: [054](054-embedded-project-layout.md)  
- Device/board assets: [053](053-device-board-assets.md)  
- Vendor HAL: [031](031-hal-libraries.md)  
- `machine`-style API: [061](061-micropython-machine-api.md)  
