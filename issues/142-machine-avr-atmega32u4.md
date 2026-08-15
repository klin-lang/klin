# 142 — `machine_avr`: ATmega32U4 (Leonardo / Micro / Pro Micro)

**Status:** 💭 planned  
**Depends on:** [061](061-micropython-machine-api.md), [107](107-later-tracks-arduino-boards.md), [`machine_avr`](https://github.com/klin-lang/machine_avr)

Spun out from queue row **A** in [107](107-later-tracks-arduino-boards.md).

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | Extend existing [`klin-lang/machine_avr`](https://github.com/klin-lang/machine_avr) |
| Boards | Arduino **Leonardo**, **Micro**, **Pro Micro** (and 32U4 clones) |
| Chip | **ATmega32U4** |
| Why here? | Same **classic megaAVR** generation as 328P / 2560 — closest win |
| Why not `machine_tinyavr`? | 32U4 is not AVRxt / UPDI tinyAVR ([141](141-machine-tinyavr.md)) |

**32U4 ≠ 328P** pin / port map. Use twin factories (e.g. `pin_out_32u4`) —
no `#ifdef` mega-driver. Do not confuse with Nano Every (ATmega4809) or tinyAVR.

## Scope (MVP)

- Pin…Adc on ATmega32U4 MMIO, same API shape as 328P where the silicon allows
- Pwm / Rc / Uart / I2c / Spi factories for 32U4 (parity with 328P `@v0.2.0` as far as hardware matches)
- Examples: `blink_leonardo` (or Micro) — document Arduino digital pin → port/bit
- Toolchain: existing `avr-gcc`; flash via `avrdude` (**Caterina** bootloader; DFU optional note)
- Host-safe `*_test.kl` for new modules

## Out of scope (MVP)

- Native **USB device** (CDC / HID / MIDI) — separate later tag or thin `@[link]` package; MVP is GPIO + buses without HID
- Wiring / `.ino` / Arduino core compatibility
- ATmega4809 (Nano Every) — not 32U4
- tinyAVR / AVR Dx — [141](141-machine-tinyavr.md)
- Board pack / `klin init` until Pin MVP exists ([075](075-board-pack-init-host.md))

## Suggested ship slices

1. **Pin** + blink on Leonardo/Micro D13 (or documented LED pin)
2. **Pwm** / **Rc** / **Uart** / **I2c** / **Spi** / **Adc** on 32U4
3. Optional thin board notes in [docs/arduino.md](../docs/arduino.md)
4. USB CDC/HID — only after Pin…Adc ships

## Links

- Parent queue: [107](107-later-tracks-arduino-boards.md)
- Catalog: [061](061-micropython-machine-api.md)
- FAQ: [docs/arduino.md](../docs/arduino.md)
- Package: https://github.com/klin-lang/machine_avr
- Official: [Leonardo](https://docs.arduino.cc/hardware/leonardo)
