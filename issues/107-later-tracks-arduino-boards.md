# 107 — Later tracks: Arduino boards beyond Uno/Mega AVR

**Status:** 💭 backlog (do **one board / silicon family at a time**; not the current step)  
**Depends on:** [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md), [075](075-board-pack-init-host.md), [`machine_avr`](https://github.com/klin-lang/machine_avr), [`machine_stm32`](https://github.com/klin-lang/machine_stm32)

## Verdict

Klin already covers **classic AVR Arduino** (Uno / Nano 328P / Mega Pin) via
[`machine_avr`](https://github.com/klin-lang/machine_avr). The boards below are
**other silicon** (or USB-AVR). Support is by **MCU family** + optional **board
pack** — never by folding Arduino IDE / Wiring / `.ino` into Klin.

Do **not** expand the current step in [sorted](sorted.md). When work starts:
new issue (or additive tag on an existing `machine_*`), external repo preferred,
compiler unchanged. Prime rule: no hidden allocation / control flow / cost.

Overview FAQ: [docs/arduino.md](../docs/arduino.md).

## Already done (context)

| Board | Chip | Klin |
|---|---|---|
| Uno / Nano / Pro Mini (328P) | ATmega328P | [`machine_avr`](https://github.com/klin-lang/machine_avr) Pin…Adc ✅ |
| Mega 2560 | ATmega2560 | Pin ✅; bus factories later |
| Nano ESP32 / ESP Dev–class | ESP32 / C3 / S3 | [`machine_esp`](https://github.com/klin-lang/machine_esp) (+ wifi/eth/ble) ✅ |
| Nano RP2040 Connect / Pico-class | RP2040 / RP2350 | [`machine_rp`](https://github.com/klin-lang/machine_rp) ✅ |

## Queue — requested boards

Work in the order below **or** by hardware on the desk. Each row = own shippable
slice (chip `machine_*` first, then thin board pack / `klin init` if useful).

| # | Board | SoC | Likely Klin home | What is needed |
|---|---|---|---|---|
| A | **Leonardo** (also Micro / Pro Micro) | **ATmega32U4** | Extend [`machine_avr`](https://github.com/klin-lang/machine_avr) | **Closest win.** New pin / port map (32U4 ≠ 328P); Pin…Adc MMIO like 328P. Native **USB device** (CDC/HID) is separate — USB stack or thin `@[link]` later; MVP can be GPIO + UART without HID. Toolchain: existing `avr-gcc`. Flash: `avrdude` (Caterina / DFU). |
| B | **Uno R4** Minima | **Renesas RA4M1** (Cortex-M4 @ 48 MHz, 256 KB flash / 32 KB SRAM, 5 V I/O) | **New** `machine_ra` / `machine_renesas` (not `machine_avr`, not STM32) | First **Renesas RA** port: clock (HOCO/PLL), IOPORT + PFS pinmux, GPT/AGT PWM, SCI UART, IIC, SPI, ADC14, optional DAC12. Startup + linker for RA4M1. Flash: CMSIS-DAP / `bossac`-class or Renesas tools — document explicitly. Optional: FSP as C engine behind Klin FFI (like IDF for ESP) **or** pure MMIO — pick one and keep costs visible. |
| B2 | **Uno R4 WiFi** | RA4M1 + **ESP32-S3** co-processor (radio) | Same `machine_ra` + [`esp_wifi`](https://github.com/klin-lang/esp_wifi) / [`esp_ble`](https://github.com/klin-lang/esp_ble) on the S3 side | Board pack must describe **two** chips and how they talk (Arduino uses a serial bridge). Do not pretend Wi‑Fi lives inside RA4M1 MMIO. |
| C | **Due** | **Atmel SAM3X8E** (Cortex-M3 @ 84 MHz, 512 KB flash / 96 KB SRAM, **3.3 V only**) | **New** `machine_sam` / `machine_sam3x` | New Arm family: PMC clocks, PIO, PWM, UART/USART, TWI, SPI, ADC12, DAC. Startup/vectors for SAM3X. Flash: `bossac` / native USB. **Not** compatible with 5 V Uno shields. No Klin SAM port today. |
| D | **Giga R1 WiFi** | **STM32H747XI** dual **M7@480 + M4@240** + Murata **1DX** Wi‑Fi/BT + ext NOR/SDRAM | Extend [`machine_stm32`](https://github.com/klin-lang/machine_stm32) with **H7 twins** (or sibling package) + board pack | **Not** a drop-in of today’s F411/F401 maps. Need H7 clock tree, GPIO AF, Pin…Adc(+Dac) on M7 first; dual-core / RPC **out of MVP**. Radio = separate module (not on-die) → thin IDF-or-vendor client later, not inside `machine_*`. Board pack: Mega form-factor pins, USB-C/USB-A host, camera/display connectors as pin maps only. |
| E | **Portenta H7** | Same **STM32H747** class as Giga (+ Wi‑Fi/BT module, HD connectors) | Share **H7 chip work** from D; Portenta **board pack** | Chip port once; board pack differs (MKR/HD pinout, carrier). Vision Shield / GPU / JPEG = later, not Pin MVP. |
| E2 | **Portenta C33** | **Renesas RA6M5** (Cortex-M33 @ ≤200 MHz) + **ESP32-C3** radio module | `machine_ra` (RA6 twin) + [`machine_esp`](https://github.com/klin-lang/machine_esp) / wifi/ble for C3 | Different from H7. Reuse Renesas patterns from Uno R4 (B) but **RA6 ≠ RA4** MMIO — twin factories, no `#ifdef` mega-driver. |

## Suggested ship order (technical, not calendar)

1. **A Leonardo Pin…** — smallest delta on existing `machine_avr`.  
2. **B Uno R4 Minima Pin…** — unlocks Renesas RA family (needed again for C33).  
3. **D STM32H7 Pin… (M7)** — unlocks both Giga and Portenta H7.  
4. **C Due** — new SAM3X family (no reuse).  
5. Board packs + radio/USB extras only after the matching chip Pin MVP.

Hardware-on-desk may reorder; do **not** start E2 before B’s RA patterns exist unless C33 is the only board available.

## Rules for each track

1. New Klin issue when implementation starts (do not implement inside this placeholder).  
2. External repo / additive tag; compiler unchanged.  
3. Board pack = pins + `startup`/`linker` + examples ([075](075-board-pack-init-host.md)); chip MMIO = `machine_*`.  
4. Radio / USB device class / dual-core RPC = **separate** packages or later tags — not hidden in Pin.  
5. No Arduino Wiring compatibility layer.  
6. ESP/RP Arduino-branded boards stay on [061](061-micropython-machine-api.md) / [062](062-targets-esp-rp.md) — not re-queued here.

## Out of scope (this issue)

- Implementation or repo scaffolding  
- Priority vs language core  
- Nano Every (ATmega4809), MKR SAMD, Nicla, Opta (open separate rows when needed)  
- Promising full µPython `machine` parity on H7 dual-core day one  

## Links

- FAQ: [docs/arduino.md](../docs/arduino.md)  
- `machine` catalog: [061](061-micropython-machine-api.md)  
- Targets: [062](062-targets-esp-rp.md)  
- Board packs / init: [075](075-board-pack-init-host.md)  
- AVR today: https://github.com/klin-lang/machine_avr  
- STM32 today (F411-class): https://github.com/klin-lang/machine_stm32  
- Official refs: [Uno R4](https://docs.arduino.cc/hardware/uno-r4-minima), [Giga R1](https://docs.arduino.cc/hardware/giga-r1-wifi/), [Due](https://docs.arduino.cc/hardware/due), [Leonardo](https://docs.arduino.cc/hardware/leonardo), [Portenta H7](https://docs.arduino.cc/hardware/portenta-h7), [Portenta C33](https://docs.arduino.cc/hardware/portenta-c33)
