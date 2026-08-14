# 087 — `machine_gd32v`: GD32VF103 (Nuclei RISC-V) Pin…Adc

**Status:** ✅ MVP `@v0.2.0` published (Pin…Adc + freestanding examples)  
**Depends on:** [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md), [086](086-machine-ch32v.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | External: [`klin-lang/machine_gd32v`](https://github.com/klin-lang/machine_gd32v) `@v0.2.0` |
| Chip MVP | **GD32VF103** (Nuclei N205; Longan Nano–class) |
| API | Pin + Pwm + Rc + Uart + I2c + Spi + Adc (real MMIO — not a stub) |
| ADC width | **12-bit** (`read_u12` → `0..=4095`) |
| vs CH32V | Separate repo ([086](086-machine-ch32v.md)) — QingKe vs Nuclei |

## Scope (`@v0.2.0`)

- Directory package `machine_gd32v/` with host-safe `*_test.kl`
- Emit-c + optional `make elf` examples (`blink_pa1`, `pwm_pa0`, `rc_pa0`, `uart_pa9`, `i2c_pb6`, `spi_pa5`, `adc_pa0`)
- Minimal freestanding `startup.S` + `linker.ld` (polling demos; no ECLIC)
- Explicit RCU clocks / AFIO `remap` — no hidden init
- MMIO from GD32VF103 map (CTL0/CTL1 GPIO, TIMER0–3, USART0/1, SPI0/1, I2C0/1, ADC0)

## Out of scope

- Combining with CH32V sources
- Full Nuclei SDK vendoring inside Klin
- GD32VW553 twins — [117](117-machine-gd32v-gd32vw553.md) (same package; Pin…Adc ✅ `@v0.8.0`)  
- Wi‑Fi on VW553 — [126](126-gd32v-wifi-sdk.md) / [`gd32v_wifi`](https://github.com/klin-lang/gd32v_wifi) [`@v0.1.0`](https://github.com/klin-lang/gd32v_wifi/releases/tag/v0.1.0) (not this file)  
- Board pack / `klin init` — [127](127-board-gd32vw553h-eval.md) / [`gd32vw553h_eval`](https://github.com/klin-lang/gd32vw553h_eval) (not this file)  
- BLE on VW553 — later sibling package, not this file

## Links

- Package: https://github.com/klin-lang/machine_gd32v  
- CH32V port: [086](086-machine-ch32v.md)  
- API catalog: [061](061-micropython-machine-api.md)
