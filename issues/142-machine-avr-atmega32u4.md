# 142 — `machine_avr`: ATmega32U4 (Leonardo / Micro / Pro Micro)

**Status:** ✅ done — [`machine_avr@v0.3.0`](https://github.com/klin-lang/machine_avr/releases/tag/v0.3.0)  
**Depends on:** [061](061-micropython-machine-api.md), [107](107-later-tracks-arduino-boards.md), [`machine_avr`](https://github.com/klin-lang/machine_avr)

Spun out from queue row **A** in [107](107-later-tracks-arduino-boards.md).

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | [`klin-lang/machine_avr`](https://github.com/klin-lang/machine_avr) `@v0.3.0` |
| Boards | Arduino **Leonardo**, **Micro**, **Pro Micro** (and 32U4 clones) |
| Chip | **ATmega32U4** |
| Why here? | Same **classic megaAVR** generation as 328P / 2560 |
| Why not `machine_tinyavr`? | 32U4 is not AVRxt / UPDI tinyAVR ([141](141-machine-tinyavr.md)) |

**32U4 ≠ 328P** pin / port map. Twin factories (`*_32u4`) — no `#ifdef`
mega-driver.

## Published

```sh
klin get github/klin-lang/machine_avr@v0.3.0
```

| API | Notes |
|---|---|
| `Port32U4` + `pin_out_32u4` / `pin_in_32u4` | D13 LED = **PC7** |
| `pwm_out_32u4` | Timer1 + Timer3 (`tim` 1 or 3) |
| `rc_out_32u4` | on top of PWM |
| `uart_out_32u4` | **USART1** (Serial1: TX PD3, RX PD2) — not USB CDC |
| `i2c_out_32u4` | TWI; Leonardo SDA=PD1, SCL=PD0 |
| `spi_out_32u4` | soft NSS |
| `adc_out_32u4` | A0 = PF7 ch 7 |
| examples | `blink_leonardo`, `pwm_leonardo`, `uart_leonardo`, `adc_leonardo` |
| `version()` | **3** |

Upstream: [machine_avr#2](https://github.com/klin-lang/machine_avr/pull/2).  
Historical apply patch (already merged): [`patches/machine_avr-v0.3.0-atmega32u4.patch`](../patches/machine_avr-v0.3.0-atmega32u4.patch).

## Out of scope (still)

- Native **USB device** (CDC / HID / MIDI) — later tag
- Wiring / `.ino`
- ATmega4809 / tinyAVR — [141](141-machine-tinyavr.md)
- Board pack / `klin init` ([075](075-board-pack-init-host.md))

## Links

- Parent queue: [107](107-later-tracks-arduino-boards.md)
- Catalog: [061](061-micropython-machine-api.md)
- FAQ: [docs/arduino.md](../docs/arduino.md)
- Package: https://github.com/klin-lang/machine_avr
- Official: [Leonardo](https://docs.arduino.cc/hardware/leonardo)
