# 062 — MCU targets beyond STM32: ESP32, RP2040, RP2350, STM8, CH32V, GD32V

**Status:** 🚧 — RP / ESP / STM8 / CH32V / GD32V via external `machine_*` (Pin…Adc); Wi‑Fi [`esp_wifi`](https://github.com/klin-lang/esp_wifi) ✅; ETH [`esp_eth`](https://github.com/klin-lang/esp_eth) ✅ (W5500); BLE [`esp_ble`](https://github.com/klin-lang/esp_ble) ✅; USB OTG [`esp_usb`](https://github.com/klin-lang/esp_usb) ✅ (device CDC); camera [`esp_camera`](https://github.com/klin-lang/esp_camera) ✅ (DVP JPEG); **ESP32-P4 Pin…Adc+Rmt+LP GPIO** ✅ [`@v0.13.0`](https://github.com/klin-lang/machine_esp/releases/tag/v0.13.0) ([114](114-machine-esp-esp32-p4.md)); RMII / classic / freestanding later
**Depends on:** [010](010-bare-metal.md); nice to have [022](022-asm-libraries.md), [027](027-svd-ergonomic-api.md), [031](031-hal-libraries.md), [053](053-device-board-assets.md), [054](054-embedded-project-layout.md)

## Context (conversation notes)

Klin emits **C** — frontend is not “STM32 only”. Today the ready
bare-metal path is mainly **STM32 Cortex-M** (`examples/stm32/…`). Question: can we
target **ESP32**, **RP2040**, **RP2350**, **STM8**, **CH32V**, **GD32V**?

## Short verdict

| Target | Realistic? | Notes |
|---|---|---|
| **RP2040** | ✅ path exists | [`machine_rp`](https://github.com/klin-lang/machine_rp) `@v0.11.0` — Pin+Pwm+Rc+Uart+I2c+Spi+Adc+**Pio**+**Dma**+**UsbCdc** (UsbCdc RP2350 first; Pio `out_pins`/TX DMA; no DAC). Pico-LCD-1.14 shield → [110](110-board-waveshare-pico-lcd-114.md). |
| **RP2350** | ✅ Arm + RISC-V | Same APIs via `*_rp2350` twins (+ UsbCdc poll). Board: Waveshare LCD-0.96 → [095](095-board-waveshare-rp2350-lcd-096.md); Pico-LCD-1.14 shield → [110](110-board-waveshare-pico-lcd-114.md). |
| **ESP32-C3** | ✅ Pin…Adc | [`machine_esp`](https://github.com/klin-lang/machine_esp) `@v0.8.0` — MMIO + LEDC; minimal **ESP-IDF** boot; no DAC; Wi‑Fi → [`esp_wifi`](https://github.com/klin-lang/esp_wifi) [101](101-esp-wifi-idf.md); ETH → [`esp_eth`](https://github.com/klin-lang/esp_eth) W5500 SPI [102](102-esp-eth-idf.md) (no on-chip EMAC); BLE → [`esp_ble`](https://github.com/klin-lang/esp_ble) [106](106-esp-ble-idf.md); USB OTG N/A on C3 (no OTG PHY); camera N/A on C3 (no DVP/LCD_CAM); IDF radio/net stacks not in `machine_esp`. |
| **ESP32-S3** | ✅ Pin…Adc+Rmt (`*_s3`) | Same package `@v0.5.0`/`@v0.6.0`/`@v0.7.0`/`@v0.8.0` — twin factories + `rmt_tx_s3` ([099](099-machine-esp-esp32-s3.md)); board Waveshare S3-Pico → [100](100-board-waveshare-esp32-s3-pico.md); Xtensa via IDF; Wi‑Fi → [101](101-esp-wifi-idf.md); ETH → [`esp_eth`](https://github.com/klin-lang/esp_eth) W5500 [102](102-esp-eth-idf.md) (no on-chip EMAC); BLE → [`esp_ble`](https://github.com/klin-lang/esp_ble) [106](106-esp-ble-idf.md); USB OTG → [`esp_usb`](https://github.com/klin-lang/esp_usb) TinyUSB CDC [108](108-esp-usb-idf.md); camera → [`esp_camera`](https://github.com/klin-lang/esp_camera) DVP JPEG [109](109-esp-camera-idf.md); IDF radio/net/USB/cam stacks not in `machine_esp`. |
| **ESP32-P4** | ✅ Pin…Adc+Rmt (`*_p4`) | Same package [`@v0.13.0`](https://github.com/klin-lang/machine_esp/releases/tag/v0.13.0) — `pin_out_p4`…`spi_out_p4` + `rmt_tx_p4` + `adc_out_p4` / `adc2_out_p4` + `pin_out_lp_p4` ([114](114-machine-esp-esp32-p4.md)); MMIO `0x500E…` / RMT `0x500A2000` / LP_ADC `0x50127000` / LP_GPIO `0x5012A000` / HP_SYS_CLKRST (**not** a copy of C3/S3 `0x6000…`); LEDC **`freq_p4`**; ADC **`read_u12_p4`** (ADC1 CH0→GPIO16; ADC2 CH0→GPIO49); HP GPIO 0..54; LP GPIO 0..15; **no** on-die Wi‑Fi/BLE (companion / other host). **On-chip EMAC** (RMII) → next [`esp_eth`](https://github.com/klin-lang/esp_eth) backend [102](102-esp-eth-idf.md) / [104](104-later-tracks-esp-network.md) E1. |
| **STM8S** | ✅ Pin…Adc (emit-c) | [`machine_stm8`](https://github.com/klin-lang/machine_stm8) `@v0.2.0` — no DAC; SDCC link later. |
| **CH32V003** | ✅ Pin…Adc | [`machine_ch32v`](https://github.com/klin-lang/machine_ch32v) `@v0.1.0` — QingKe RV32EC ([086](086-machine-ch32v.md)). |
| **GD32VF103** | ✅ Pin…Adc | [`machine_gd32v`](https://github.com/klin-lang/machine_gd32v) `@v0.2.0` — Nuclei N205 ([087](087-machine-gd32v.md)). |
| **ESP32** (classic / other) | Later | Classic = **Xtensa**; C6 etc. separate from C3/S3/P4. |

## What already carries to these MCUs

- single `.c` emit, checker, `#line`
- `@[codename]` / ISR, `@[cimport]` / `@[link]` (C and ASM)
- SVD → typed registers ([011](011-svd.md) / [027](027-svd-ergonomic-api.md)), when chip SVD exists
- rule: startup / vector table / clock stay explicit (not language magic)

## What is not out of the box

- generic board pack / Klin-tree `examples/rp2040/…` (lives in [`machine_rp`](https://github.com/klin-lang/machine_rp); Waveshare RP2350-LCD-0.96 → [`waveshare_rp2350_lcd_096`](https://github.com/klin-lang/waveshare_rp2350_lcd_096) [095](095-board-waveshare-rp2350-lcd-096.md); Waveshare Pico-LCD-1.14 shield → [`waveshare_pico_lcd_114`](https://github.com/klin-lang/waveshare_pico_lcd_114) [110](110-board-waveshare-pico-lcd-114.md); Adafruit RP2040 CAN Feather → [`adafruit_rp2040_can_feather`](https://github.com/klin-lang/adafruit_rp2040_can_feather) [098](098-board-adafruit-rp2040-can-feather.md); Waveshare ESP32-S3-Pico → [`waveshare_esp32_s3_pico`](https://github.com/klin-lang/waveshare_esp32_s3_pico) [100](100-board-waveshare-esp32-s3-pico.md))
- automatic ESP-IDF or pico-sdk in Klin CLI (example ships its own `idf.py` flow)
- freestanding ESP image (no IDF)
- Classic Xtensa ESP32 / C6 ports (S3 Pin…Adc ✅ → [099](099-machine-esp-esp32-s3.md); P4 Pin…Adc+Rmt ✅ → [114](114-machine-esp-esp32-p4.md); P4 RMII via [102](102-esp-eth-idf.md) later)
- hardware DAC on RP / ESP-C3/S3/P4 / STM8S / F411

## Order sketch

1. **RP2040** blink + `machine` Pin — ✅  
2. **RP2350** Arm / RISC-V blink — ✅  
3. **ESP32-C3** Pin + blink — ✅  
4. **Pwm** / **Rc** on RP + ESP — ✅  
5. **Uart** / **I2c** / **Spi** / **Adc** on RP + ESP + STM8 — ✅ (`machine_rp@v0.6.0`, `machine_esp@v0.4.0`, `machine_stm8@v0.2.0`)  
6. **ESP32-S3** Pin…Adc twins (`*_s3`) + Rmt TX — ✅ (`machine_esp@v0.5.0`/`@v0.6.0`/`@v0.7.0`; [099](099-machine-esp-esp32-s3.md); board WS2812 → [100](100-board-waveshare-esp32-s3-pico.md))  
7. **Pio** on RP — ✅ (`machine_rp@v0.8.0`; board WS2812 PIO → [095](095-board-waveshare-rp2350-lcd-096.md); not on other MCU families)  
8. **Dma** on RP — ✅ (`machine_rp@v0.9.0`; board DMA→SPI1 LCD → [095](095-board-waveshare-rp2350-lcd-096.md))  
9. **UsbCdc** on RP2350 — ✅ (`machine_rp@v0.10.0`; board Type-C console → [095](095-board-waveshare-rp2350-lcd-096.md); RP2040 later)  
10. **PIO-as-SPI** helpers — ✅ (`machine_rp@v0.11.0`; board LCD remux → [095](095-board-waveshare-rp2350-lcd-096.md))  
11. **CH32V003** Pin…Adc — ✅ (`machine_ch32v@v0.1.0`; [086](086-machine-ch32v.md))  
12. **GD32VF103** Pin…Adc — ✅ (`machine_gd32v@v0.2.0`; [087](087-machine-gd32v.md))  
13. **Wi‑Fi** (ESP-IDF STA + SoftAP + scan + link) — ✅ [`esp_wifi`](https://github.com/klin-lang/esp_wifi) `@v0.4.0` ([101](101-esp-wifi-idf.md); W1–W3 → [104](104-later-tracks-esp-network.md); DHCP default, optional static; not in `machine_*`)  
14. **Ethernet** (ESP-IDF; W5500 SPI first) — ✅ [`esp_eth`](https://github.com/klin-lang/esp_eth) `@v0.1.2` ([102](102-esp-eth-idf.md); RMII later, same package)  
15. **BLE** (ESP-IDF NimBLE GAP/GATT + bond + UUID16/128 + privacy + Mesh OnOff) — ✅ [`esp_ble`](https://github.com/klin-lang/esp_ble) `@v0.10.0` ([106](106-esp-ble-idf.md); not in `machine_*`)  
16. **USB OTG** (ESP-IDF TinyUSB device CDC) — ✅ [`esp_usb`](https://github.com/klin-lang/esp_usb) `@v0.1.0` ([108](108-esp-usb-idf.md); not in `machine_*`; host / other classes later)  
17. **Camera** (ESP-IDF esp32-camera DVP JPEG) — ✅ [`esp_camera`](https://github.com/klin-lang/esp_camera) `@v0.1.0` ([109](109-esp-camera-idf.md); not in `machine_*`; CSI / RGB stream later)  
18. **Pico LCD shield** (Waveshare Pico-LCD-1.14 ST7789) — ✅ [`waveshare_pico_lcd_114`](https://github.com/klin-lang/waveshare_pico_lcd_114) `@v0.1.0` ([110](110-board-waveshare-pico-lcd-114.md); board pack, not `machine_*`)  
19. **ESP32-P4** — Pin…Adc+Rmt+LP GPIO ✅ `machine_esp@v0.13.0` (`*_p4`; [114](114-machine-esp-esp32-p4.md); ADC2 ✅; LP GPIO ✅); [`esp_eth`](https://github.com/klin-lang/esp_eth) **RMII** backend later (on-chip EMAC; preferred first RMII target vs classic ESP32); Wi‑Fi/BLE only via companion / other host, not on-die; USB OTG can use [`esp_usb`](https://github.com/klin-lang/esp_usb) when P4 board work starts  
20. **Later tags** (USB host classes; camera CSI/stream; LCD font/S3 SPI / other shield sizes) — see [103](103-later-tracks-ble-usb-camera-lcd.md) / [108](108-esp-usb-idf.md) / [109](109-esp-camera-idf.md) / [110](110-board-waveshare-pico-lcd-114.md)  
21. **Later network** (RMII…) — 🔨 Wi‑Fi W1–W3 + dual + sockets + HTTP/TLS ✅ [`esp_netif_dual`](https://github.com/klin-lang/esp_netif_dual) [113](113-esp-netif-dual-idf.md); ETH rest 💭 [104](104-later-tracks-esp-network.md)  
22. **Later IoT** (MQTT / OTA…) — 💭 maybe [105](105-later-tracks-iot.md) (sockets+HTTP ✅; MQTT next)  
23. **Later Arduino boards** (Leonardo / Uno R4 / Due / Giga / Portenta) — 💭 [107](107-later-tracks-arduino-boards.md) (one silicon family at a time; FAQ [docs/arduino.md](../docs/arduino.md))  
24. Classic ESP32 / C6 / freestanding ESP / SDCC STM8 — later  

## Out of scope

- implementation in this issue (placeholder / decision only)
- promise of full portability like µPython between ports
- priority relative to language core / current STM32 path

## Links

- RP package: https://github.com/klin-lang/machine_rp  
- ESP package: https://github.com/klin-lang/machine_esp  
- ESP Wi‑Fi (IDF, not `machine_*`): https://github.com/klin-lang/esp_wifi ([101](101-esp-wifi-idf.md))  
- ESP Ethernet (IDF, not `machine_*`): https://github.com/klin-lang/esp_eth ([102](102-esp-eth-idf.md))  
- ESP sockets (LwIP BSD, not `machine_*`): https://github.com/klin-lang/esp_sockets ([111](111-esp-sockets-idf.md))  
- ESP HTTP/TLS (IDF client, not `machine_*`): https://github.com/klin-lang/esp_http ([112](112-esp-http-idf.md))  
- ESP dual Wi‑Fi+ETH glue (IDF netif, not `machine_*`): https://github.com/klin-lang/esp_netif_dual ([113](113-esp-netif-dual-idf.md))  
- ESP BLE (IDF NimBLE, not `machine_*`): https://github.com/klin-lang/esp_ble ([106](106-esp-ble-idf.md))  
- ESP USB OTG (IDF TinyUSB, not `machine_*`): https://github.com/klin-lang/esp_usb ([108](108-esp-usb-idf.md))  
- ESP camera (IDF esp32-camera, not `machine_*`): https://github.com/klin-lang/esp_camera ([109](109-esp-camera-idf.md))  
- Pico LCD shield: https://github.com/klin-lang/waveshare_pico_lcd_114 ([110](110-board-waveshare-pico-lcd-114.md))  
- Later ESP/Pico tracks: [103](103-later-tracks-ble-usb-camera-lcd.md)  
- Later ESP network tracks: [104](104-later-tracks-esp-network.md)  
- Later IoT tracks (maybe): [105](105-later-tracks-iot.md)  
- Later Arduino boards: [107](107-later-tracks-arduino-boards.md) / [docs/arduino.md](../docs/arduino.md)  

- STM8 package: https://github.com/klin-lang/machine_stm8  
- CH32V package: https://github.com/klin-lang/machine_ch32v ([086](086-machine-ch32v.md))  
- GD32V package: https://github.com/klin-lang/machine_gd32v ([087](087-machine-gd32v.md))  
- Bare-metal STM32: [010](010-bare-metal.md)  
- Project layout: [054](054-embedded-project-layout.md)  
- Device/board assets: [053](053-device-board-assets.md)  
- Vendor HAL: [031](031-hal-libraries.md)  
- `machine`-style API: [061](061-micropython-machine-api.md)  
- ESP32-P4 Pin…Adc+Rmt: [114](114-machine-esp-esp32-p4.md)  
