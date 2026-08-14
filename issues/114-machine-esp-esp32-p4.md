# 114 — `machine_esp` ESP32-P4 (Pin…Spi twin factories)

**Status:** ✅ published [`@v0.8.0`](https://github.com/klin-lang/machine_esp/releases/tag/v0.8.0) (Pin) / [`@v0.9.0`](https://github.com/klin-lang/machine_esp/releases/tag/v0.9.0) (Pwm…Spi)  
**Depends on:** [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** (emit C + ESP-IDF toolchain, same as C3/S3) |
| Where does the code live? | External: [`klin-lang/machine_esp`](https://github.com/klin-lang/machine_esp) |
| Pattern | Twin factories like S3 `*_s3` / RP `*_rp2350` — **no** shared `#ifdef` mega-driver |
| C3 / S3 | Unchanged: `pin_out` / `pin_out_s3` / … |
| P4 | Explicit: `pin_out_p4` / `pin_in_p4` / `pwm_out_p4` / `rc_out_p4` / `uart_out_p4` / `i2c_out_p4` / `spi_out_p4` |

P4 MMIO is **not** a copy of C3/S3 (`0x6000…`). GPIO / IO_MUX live in the
`0x500E…` band; peri clocks are **HP_SYS_CLKRST** `0x500E6000` (IDF `soc` / TRM).

## What changed vs C3/S3 (MMIO, not ISA)

1. **Bases** — GPIO `0x500E0000`, IO_MUX `0x500E1000`; LEDC `0x500D3000`; UART0 `0x500CA000` + n×`0x1000`; I2C0 `0x500C4000`; SPI2 `0x500D0000`  
2. **HP pads** — GPIO **0..54** (LP GPIO is a different controller — later)  
3. **Matrix** — `SIG_GPIO_OUT=256`, OEN_SEL bit **10** (same shape as S3, not C3)  
4. **GPIO ≥ 32** — `OUT1` / `ENABLE1` / `IN1`  
5. **Clock** — `GPIO_CLOCK_GATE` bit 0; peri via HP_SYS_CLKRST (not SYSTEM `0x600C…`)  
6. **LEDC timer** — DUTY_RES `[4:0]`, CLK_DIV `[22:5]`, RST bit **24**, PARA_UP bit **26**; `LEDC_CONF` `@ +0x170`. Call **`freq_p4`**, not C3/S3 `freq`.  
7. **Signals** — UART0..4 TX/RX **10/13/16/19/22**; LEDC_LS_SIG_OUT0..7 **126..133**; I2C0 SCL/SDA **68/69**; SPI2 CK/Q/D **53/54/55**  
8. **Examples** — `idf.py set-target esp32p4`

Dual RISC-V vs C3 RISC-V / S3 Xtensa is handled by **ESP-IDF**, not Klin.

## Scope

| Tag | Contents |
|---|---|
| [`@v0.8.0`](https://github.com/klin-lang/machine_esp/releases/tag/v0.8.0) | `pin_out_p4` / `pin_in_p4` + `examples/blink_p4` (default GPIO2; edit for board) |
| [`@v0.9.0`](https://github.com/klin-lang/machine_esp/releases/tag/v0.9.0) | Pwm/Rc/Uart/I2c/Spi `*_p4` + examples `pwm_p4` / `rc_p4` / `uart_p4` / `i2c_p4` / `spi_p4` |

`version()` → `9`.

## Out of scope (this tag)

- Adc / Rmt `*_p4` — later (P4 oneshot is **LP_ADC**, not HP `0x500DE000` SARADC)  
- LP GPIO  
- RMII Ethernet — [`esp_eth`](https://github.com/klin-lang/esp_eth) [104](104-later-tracks-esp-network.md) **E1** (P4 preferred first RMII host; does not require more `machine_esp` P4 APIs)  
- On-die Wi‑Fi / BLE — **none** on P4 (companion / other host; not `esp_wifi` on P4 alone)  
- Freestanding (no IDF)  
- Board pack / `klin init` for a specific P4 module  
- Classic ESP32 / C6

## Usage

```klin
import "github/klin-lang/machine_esp" machine

let led = machine.pin_out_p4(2)
let pwm = machine.pwm_out_p4(2, 0, 0, 80000000)
pwm.freq_p4(1000)
let u = machine.uart_out_p4(0, 17, 18, 80000000, 115200)
let bus = machine.i2c_out_p4(0, 8, 9, 40000000, 100000)
let s = machine.spi_out_p4(2, 12, 11, 13, 80000000, 1000000, 0)
let servo = machine.rc_out_p4(2, 0, 0, 80000000, 50, 1000, 2000)
```

`uart_out_p4` accepts instance **0..=4**. I2C0 only. SPI2 only. Soft SPI CS via a separate `Pin`.

```sh
klin get github/klin-lang/machine_esp@v0.9.0
```

## Links

- Repo: https://github.com/klin-lang/machine_esp  
- PR: https://github.com/klin-lang/machine_esp/pull/8 (Pin), [#9](https://github.com/klin-lang/machine_esp/pull/9) (Pwm…Spi)  
- Tags: [v0.8.0](https://github.com/klin-lang/machine_esp/releases/tag/v0.8.0), [v0.9.0](https://github.com/klin-lang/machine_esp/releases/tag/v0.9.0)  
- Catalog: [061](061-micropython-machine-api.md), targets [062](062-targets-esp-rp.md)  
- S3 twin (same package): [099](099-machine-esp-esp32-s3.md)  
- RMII later: [102](102-esp-eth-idf.md) / [104](104-later-tracks-esp-network.md)
