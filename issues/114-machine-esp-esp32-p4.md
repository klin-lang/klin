# 114 — `machine_esp` ESP32-P4 (Pin…Adc+Rmt twin factories)

**Status:** ✅ published [`@v0.8.0`](https://github.com/klin-lang/machine_esp/releases/tag/v0.8.0) (Pin) / [`@v0.9.0`](https://github.com/klin-lang/machine_esp/releases/tag/v0.9.0) (Pwm…Spi) / [`@v0.10.0`](https://github.com/klin-lang/machine_esp/releases/tag/v0.10.0) (Rmt TX) / [`@v0.11.0`](https://github.com/klin-lang/machine_esp/releases/tag/v0.11.0) (Adc1) / [`@v0.12.0`](https://github.com/klin-lang/machine_esp/releases/tag/v0.12.0) (Adc2) / [`@v0.13.0`](https://github.com/klin-lang/machine_esp/releases/tag/v0.13.0) (LP GPIO) / [`@v0.14.0`](https://github.com/klin-lang/machine_esp/releases/tag/v0.14.0) (regi2c) / [`@v0.15.0`](https://github.com/klin-lang/machine_esp/releases/tag/v0.15.0) (LP UART)  
**Depends on:** [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** (emit C + ESP-IDF toolchain, same as C3/S3) |
| Where does the code live? | External: [`klin-lang/machine_esp`](https://github.com/klin-lang/machine_esp) |
| Pattern | Twin factories like S3 `*_s3` / RP `*_rp2350` — **no** shared `#ifdef` mega-driver |
| C3 / S3 | Unchanged: `pin_out` / `pin_out_s3` / … |
| P4 | Explicit: `pin_out_p4` / `pin_in_p4` / `pin_out_lp_p4` / `pin_in_lp_p4` / `pwm_out_p4` / `rc_out_p4` / `uart_out_p4` / `uart_out_lp_p4` / `i2c_out_p4` / `spi_out_p4` / `rmt_tx_p4` / `adc_out_p4` / `adc2_out_p4` / `adc_cal_init_p4` |

P4 MMIO is **not** a copy of C3/S3 (`0x6000…`). GPIO / IO_MUX live in the
`0x500E…` band; peri clocks are **HP_SYS_CLKRST** `0x500E6000` (IDF `soc` / TRM).
ADC oneshot is **LP_ADC** `0x50127000` (not HP SARADC `0x500DE000`): ADC1 MEAS1, ADC2 MEAS2.
LP GPIO is a **different** controller: LP_GPIO `0x5012A000`, LP_IOMUX `0x5012B000`.
SAR regi2c master is **LP_I2C_ANA_MST** `0x50124000` (slave `0x69`), not C3/S3 I2C_MST `0x6000E…`.

## What changed vs C3/S3 (MMIO, not ISA)

1. **Bases** — GPIO `0x500E0000`, IO_MUX `0x500E1000`; LEDC `0x500D3000`; UART0 `0x500CA000` + n×`0x1000`; I2C0 `0x500C4000`; SPI2 `0x500D0000`; RMT `0x500A2000`; LP_ADC `0x50127000`; LP_UART `0x50121000`; LP_I2C_ANA_MST `0x50124000`; LP_GPIO `0x5012A000`; LP_IOMUX `0x5012B000`  
2. **HP pads** — GPIO **0..54**. **LP GPIO** 0..15 (`pin_out_lp_p4` / `pin_in_lp_p4`) — same physical pads as HP 0..15; do not call both on one pad. `SIG_LP_GPIO_OUT=32` in bits **[8:3]**.  
3. **Matrix** — `SIG_GPIO_OUT=256`, OEN_SEL bit **10** (same shape as S3, not C3). LP matrix: OUT_SEL bits **[8:3]**, IN_SEL bits **[7:2]** + SIG bit **1**.  
4. **GPIO ≥ 32** — `OUT1` / `ENABLE1` / `IN1`  
5. **Clock** — `GPIO_CLOCK_GATE` bit 0; peri via HP_SYS_CLKRST (not SYSTEM `0x600C…`); ADC oneshot + LP IOMUX + LP UART via **LPPERI** `0x50120000` (`CK_EN_LP_IOMUX` bit 20; `CK_EN_LP_UART` bit 29)  
6. **LEDC timer** — DUTY_RES `[4:0]`, CLK_DIV `[22:5]`, RST bit **24**, PARA_UP bit **26**; `LEDC_CONF` `@ +0x170`. Call **`freq_p4`**, not C3/S3 `freq`.  
7. **ADC oneshot** — LP_ADC RTC path. Call **`read_u12_p4` / `read_u16_p4`**, not C3/S3 `read_u12`. ADC1 CH0→GPIO16 … CH7→GPIO23; ADC2 `adc2_out_p4` CH0→GPIO49 … CH5→GPIO54 (hw pad = channel+2). SAR regi2c: **`adc_cal_init_p4`** (DREF=4; not inside `adc_out_p4`); slave `0x69`.  
8. **Signals** — UART0..4 TX/RX **10/13/16/19/22**; LP UART TX/RX idx **2**; LEDC_LS_SIG_OUT0..7 **126..133**; I2C0 SCL/SDA **68/69**; SPI2 CK/Q/D **53/54/55**; RMT_SIG_OUT0..3 **246..249**  
9. **Examples** — `idf.py set-target esp32p4`

Dual RISC-V vs C3 RISC-V / S3 Xtensa is handled by **ESP-IDF**, not Klin.

## Scope

| Tag | Contents |
|---|---|
| [`@v0.8.0`](https://github.com/klin-lang/machine_esp/releases/tag/v0.8.0) | `pin_out_p4` / `pin_in_p4` + `examples/blink_p4` (default GPIO2; edit for board) |
| [`@v0.9.0`](https://github.com/klin-lang/machine_esp/releases/tag/v0.9.0) | Pwm/Rc/Uart/I2c/Spi `*_p4` + examples `pwm_p4` / `rc_p4` / `uart_p4` / `i2c_p4` / `spi_p4` |
| [`@v0.10.0`](https://github.com/klin-lang/machine_esp/releases/tag/v0.10.0) | `rmt_tx_p4` (TX ch 0..=3, `put`/`start`/`wait_done`; no DMA/carrier) + `examples/rmt_p4` |
| [`@v0.11.0`](https://github.com/klin-lang/machine_esp/releases/tag/v0.11.0) | `adc_out_p4` + `read_u12_p4` / `read_u16_p4` (ADC1 CH0→GPIO16 … CH7→GPIO23) + `examples/adc_p4` |
| [`@v0.12.0`](https://github.com/klin-lang/machine_esp/releases/tag/v0.12.0) | `adc2_out_p4` (ADC2 CH0→GPIO49 … CH5→GPIO54; hw pad = channel+2) + `examples/adc2_p4` |
| [`@v0.13.0`](https://github.com/klin-lang/machine_esp/releases/tag/v0.13.0) | `pin_out_lp_p4` / `pin_in_lp_p4` (LP GPIO 0..15; same pads as HP 0..15) + `examples/blink_lp_p4` |
| [`@v0.14.0`](https://github.com/klin-lang/machine_esp/releases/tag/v0.14.0) | `adc_cal_init_p4` / `adc_cal_init_code_p4` / `adc_cal_encal_gnd_p4` (LP_I2C_ANA_MST, slave `0x69`) + `examples/adc_cal_p4` |
| [`@v0.15.0`](https://github.com/klin-lang/machine_esp/releases/tag/v0.15.0) | `uart_out_lp_p4` → `UartLp` (LP UART `0x50121000`; LP matrix idx 2; XTAL_D2) + `examples/uart_lp_p4` |

`version()` → `15`.

## Out of scope (this tag)

- eFuse / curve-fitting / IDF `adc_cali_*`  
- LP GPIO hold / wakeup / LP I2C  
- RMII Ethernet — [`esp_eth`](https://github.com/klin-lang/esp_eth) [104](104-later-tracks-esp-network.md) **E1** (P4 preferred first RMII host; does not require more `machine_esp` P4 APIs)  
- On-die Wi‑Fi / BLE — **none** on P4 (companion / other host; not `esp_wifi` on P4 alone)  
- Freestanding (no IDF)  
- Board pack / `klin init` for a specific P4 module  
- Classic ESP32 / C6

## Usage

```klin
import "github/klin-lang/machine_esp" machine

let led = machine.pin_out_p4(2)
let lp = machine.pin_out_lp_p4(2)  // same pad as HP 2 — do not mix with pin_out_p4
let pwm = machine.pwm_out_p4(2, 0, 0, 80000000)
pwm.freq_p4(1000)
let u = machine.uart_out_p4(0, 17, 18, 80000000, 115200)
let lp_u = machine.uart_out_lp_p4(14, 15, 20000000, 115200)  // UartLp; XTAL_D2
let bus = machine.i2c_out_p4(0, 8, 9, 40000000, 100000)
let s = machine.spi_out_p4(2, 12, 11, 13, 80000000, 1000000, 0)
let servo = machine.rc_out_p4(2, 0, 0, 80000000, 50, 1000, 2000)
let rmt = machine.rmt_tx_p4(2, 0, 80000000)
machine.adc_cal_init_p4()
let adc = machine.adc_out_p4(16, 0)
let raw = adc.read_u12_p4()
let adc2 = machine.adc2_out_p4(49, 0)
```

`uart_out_p4` accepts instance **0..=4**. I2C0 only. SPI2 only. Soft SPI CS via a separate `Pin`.
LP UART: **`uart_out_lp_p4`** — one instance, LP GPIO 0..15, sclk **XTAL_D2** (pass `20000000`). Returns **`UartLp`** (FIFO bits ≠ HP `Uart`). Do not also call `uart_out_p4` / `pin_out_p4` / `pin_out_lp_p4` on the same pads.
`rmt_tx_p4` is TX channels **0..=3** only (no DMA / carrier).
ADC oneshot is LP_ADC — call **`read_u12_p4`**, not `read_u12`. ADC2: `adc2_out_p4`.
SAR regi2c: **`adc_cal_init_p4`** (DREF=4) — call explicitly; not inside `adc_out_p4`. No eFuse curve-fit.
LP GPIO 0..15: **`pin_out_lp_p4` / `pin_in_lp_p4`** — same pads as HP 0..15; do not call both on one pad.

```sh
klin get github/klin-lang/machine_esp@v0.15.0
```

## Links

- Repo: https://github.com/klin-lang/machine_esp  
- PR: https://github.com/klin-lang/machine_esp/pull/8 (Pin), [#9](https://github.com/klin-lang/machine_esp/pull/9) (Pwm…Spi), [#10](https://github.com/klin-lang/machine_esp/pull/10) (Rmt), [#11](https://github.com/klin-lang/machine_esp/pull/11) (Adc1), [#12](https://github.com/klin-lang/machine_esp/pull/12) (Adc2), [#13](https://github.com/klin-lang/machine_esp/pull/13) (LP GPIO), [#14](https://github.com/klin-lang/machine_esp/pull/14) (regi2c), [#15](https://github.com/klin-lang/machine_esp/pull/15) (LP UART)  
- Tags: [v0.8.0](https://github.com/klin-lang/machine_esp/releases/tag/v0.8.0), [v0.9.0](https://github.com/klin-lang/machine_esp/releases/tag/v0.9.0), [v0.10.0](https://github.com/klin-lang/machine_esp/releases/tag/v0.10.0), [v0.11.0](https://github.com/klin-lang/machine_esp/releases/tag/v0.11.0), [v0.12.0](https://github.com/klin-lang/machine_esp/releases/tag/v0.12.0), [v0.13.0](https://github.com/klin-lang/machine_esp/releases/tag/v0.13.0), [v0.14.0](https://github.com/klin-lang/machine_esp/releases/tag/v0.14.0), [v0.15.0](https://github.com/klin-lang/machine_esp/releases/tag/v0.15.0)  
- Catalog: [061](061-micropython-machine-api.md), targets [062](062-targets-esp-rp.md)  
- S3 twin (same package): [099](099-machine-esp-esp32-s3.md)  
- RMII later: [102](102-esp-eth-idf.md) / [104](104-later-tracks-esp-network.md)
