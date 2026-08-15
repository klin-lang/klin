# 141 — `machine_tinyavr`: tinyAVR 0/1/2-series Pin…Adc

**Status:** 💭 planned  
**Depends on:** [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md), [021](021-c-libraries.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | External: [`klin-lang/machine_tinyavr`](https://github.com/klin-lang/machine_tinyavr) (new repo) |
| Chip MVP | **ATtiny1624** (tinyAVR **2-series**, 14-pin; typical new design) |
| Family | Modern **AVRxt** + **UPDI** — **not** classic megaAVR, **not** ATxmega |
| API MVP | Pin + Pwm + Rc + Uart + I2c + Spi + Adc (same shape as other `machine_*`) |
| vs `machine_avr` | Separate package. 328P/2560/32U4 stay in [`machine_avr`](https://github.com/klin-lang/machine_avr). |
| vs `machine_xmega` | Separate ([`machine_xmega`](https://github.com/klin-lang/machine_xmega) A1U-class). |

Do **not** fold tinyAVR into `machine_avr`. Different core, PORTMUX / TCA / TCB /
USART map, and programming (UPDI vs ISP / Caterina).

## Scope (MVP)

- Directory package `machine_tinyavr/` with host-safe `*_test.kl`
- Freestanding blink + Pin…Adc examples for **ATtiny1624**
- Explicit clocks / PORTMUX — no hidden init
- Toolchain: `avr-gcc` + UPDI flash (`pymcuprog` / `avrdude` UPDI) documented
- MMIO from Microchip tinyAVR 2-series map for the 1624

## Out of scope (MVP)

- Classic ATtiny25/45/85
- ATxmega (`machine_xmega`)
- AVR Dx (separate issue later; optional twin factories in this repo **only after** 1624 Pin…Adc ships)
- USB device / DAC day one (add only where silicon has them, as later tags)
- Arduino Wiring / `.ino`
- Compiler changes

## Links

- API catalog: [061](061-micropython-machine-api.md)
- Classic megaAVR (Uno / Mega / Leonardo): [`machine_avr`](https://github.com/klin-lang/machine_avr); Leonardo → [142](142-machine-avr-atmega32u4.md)
- ATxmega: [`machine_xmega`](https://github.com/klin-lang/machine_xmega)
- Arduino FAQ: [docs/arduino.md](../docs/arduino.md)
- Targets overview: [062](062-targets-esp-rp.md)
