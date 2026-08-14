# 134 — `machine_ch32v`: CH32V003 (QingKe RISC-V) Pin…Adc

**Status:** ✅ MVP `@v0.1.0` published  
**Formerly:** `086` (renumbered to resolve duplicate issue numbers).

**Depends on:** [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md), [010](010-bare-metal.md), [021](021-c-libraries.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | External: [`klin-lang/machine_ch32v`](https://github.com/klin-lang/machine_ch32v) |
| Chip MVP | **CH32V003** (QingKe RV32EC, HSI ≈ 24 MHz) |
| API | Pin + Pwm + Rc + Uart + I2c + Spi + Adc (same shape as other `machine_*`) |
| ADC width | **10-bit** (`read_u12` name kept for API parity → `0..=1023`) |
| vs GD32V | Separate repo ([135](135-machine-gd32v.md)) — different core/vectors |

## Scope (MVP `@v0.1.0`)

- Directory package `machine_ch32v/` with host-safe `*_test.kl`
- Freestanding examples (`blink_pd0`, `pwm_pd4`, `rc_pd4`, `uart_pd5`, `i2c_pc1`, `spi_pc5`, `adc_pd2`) + minimal RISC-V startup/linker
- Explicit clocks / AFIO `remap` — no hidden init
- MMIO from WCH CH32V003 map (CFGLR GPIO, TIM1/2, USART1, SPI1, I2C1, ADC1)

## Out of scope

- CH32V203 / V307 / USB / BLE variants
- Vendor EVT / MounRiver as a dependency
- Wi‑Fi / Ethernet
## Published

```sh
klin get github/klin-lang/machine_ch32v@v0.1.0
```

## Links

- Companion GD32V port: [135](135-machine-gd32v.md)
- API catalog: [061](061-micropython-machine-api.md)
- Other RISC-V (ESP-C3 / RP2350): [062](062-targets-esp-rp.md)
