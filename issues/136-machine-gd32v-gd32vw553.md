# 136 — `machine_gd32v` GD32VW553 (Pin…Adc twins)

**Status:** ✅ Pin…Adc [`@v0.8.0`](https://github.com/klin-lang/machine_gd32v/releases/tag/v0.8.0) (Pin [`@v0.3.0`](https://github.com/klin-lang/machine_gd32v/releases/tag/v0.3.0); Pwm+Rc [`@v0.4.0`](https://github.com/klin-lang/machine_gd32v/releases/tag/v0.4.0); Uart [`@v0.5.0`](https://github.com/klin-lang/machine_gd32v/releases/tag/v0.5.0); I2c [`@v0.6.0`](https://github.com/klin-lang/machine_gd32v/releases/tag/v0.6.0); Spi [`@v0.7.0`](https://github.com/klin-lang/machine_gd32v/releases/tag/v0.7.0); Adc [`@v0.8.0`](https://github.com/klin-lang/machine_gd32v/releases/tag/v0.8.0))
**Depends on:** [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md), [135](135-machine-gd32v.md)
**Formerly:** `117` (renumbered to resolve duplicate issue numbers).

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | Same package: [`klin-lang/machine_gd32v`](https://github.com/klin-lang/machine_gd32v) |
| Pattern | Twin factories `*_vw553` — **no** shared `#ifdef` mega-driver |
| VF103 | Unchanged: `pin_out` / `pwm_out` / `rc_out` / `uart_out` / `i2c_out` / `spi_out` / … ([135](135-machine-gd32v.md)) |
| VW553 | Explicit: `pin_out_vw553` / `pin_in_vw553` [`@v0.3.0`](https://github.com/klin-lang/machine_gd32v/releases/tag/v0.3.0); `pwm_out_vw553` / `rc_out_vw553` [`@v0.4.0`](https://github.com/klin-lang/machine_gd32v/releases/tag/v0.4.0); `uart_out_vw553` [`@v0.5.0`](https://github.com/klin-lang/machine_gd32v/releases/tag/v0.5.0); `i2c_out_vw553` → `I2cVw553` [`@v0.6.0`](https://github.com/klin-lang/machine_gd32v/releases/tag/v0.6.0); `spi_out_vw553` [`@v0.7.0`](https://github.com/klin-lang/machine_gd32v/releases/tag/v0.7.0); `adc_out_vw553` → `AdcVw553` [`@v0.8.0`](https://github.com/klin-lang/machine_gd32v/releases/tag/v0.8.0). |

VW553 MMIO is **not** a copy of VF103. VF103 is Nuclei **N205** with F1-style
GPIO (`CTL0`/`CTL1` @ `0x40010800`, RCU APB2 @ `0x40021000`). VW553 is Nuclei
**N307** @ 160 MHz with F4-style GPIO (`CTL` 2-bit/pin @ `0x40020000`, RCU
`0x40023800`). Ports **A..C** only (datasheet). On-die **Wi‑Fi 6 + BLE 5.2**
are **not** `machine_*` — later sibling packages over the GigaDevice VW55x
SDK (same split as [`esp_wifi`](https://github.com/klin-lang/esp_wifi) vs
`machine_esp`).

## What changed vs VF103 (MMIO, not ISA)

1. **GPIO** — `GPIOA` `0x40020000`, `GPIOB` `+0x400`, `GPIOC` `+0x800`. Registers:
   `CTL` `+0x00` (2 bits/pin: 00 in / 01 out / 10 AF / 11 analog), `OMODE` `+0x04`,
   `OSPD` `+0x08`, `PUD` `+0x0C`, `ISTAT` `+0x10`, `OCTL` `+0x14`, `BOP` `+0x18`
   (set `[15:0]`, clear `[31:16]`).
2. **RCU** — `0x40023800`. GPIO clocks: `RCU_AHB1EN` `+0x30` bits `PAEN=0`,
   `PBEN=1`, `PCEN=2`. Timer clocks: `RCU_APB1EN` `+0x40` (`TIMER1EN=0`,
   `TIMER2EN=1`), `RCU_APB2EN` `+0x44` (`TIMER0EN=0`, `TIMER15EN=17`,
   `TIMER16EN=18`). USART clocks: APB1 `USART0EN=18`, `UART1EN=17`; APB2
   `UART2EN=4`. I2C clocks: APB1 `I2C0EN=21`, `I2C1EN=22`. SPI clock: APB2
   `SPIEN=12`. ADC clock: APB2 `ADCEN=8`. Default IRC16M **16 MHz** (not VF103 IRC8M).
3. **Ports** — A..C, pins 0..=15 (package may bond fewer pads; edit the example).
4. **AF** — `GPIOx_AFSEL0/1` `+0x20`/`+0x24` (4 bits/pin, AF 0..=15). **Not**
   VF103 AFIO remap. Caller passes `af` (PA0 TIMER1_CH0 = **AF1**, PA0
   USART0_TX = **AF0**, PA2 I2C0_SCL = **AF2**, PA5 SPI_SCK = **AF4**,
   PA0 ADC_IN0 = analog / no AF, datasheet Table 2-5).
5. **Timers** — TIMER0 `0x40010000` (advanced, CCHP MOE); TIMER1 `0x40000000` /
   TIMER2 `0x40000400` (32-bit CNT/CAR); TIMER15 `0x40018000` / TIMER16
   `0x40018400` (CCHP MOE). TIMER5 is basic — no PWM channels. Same `Pwm` /
   `Rc` methods as VF103; `freq()` still uses a 16-bit PSC/CAR path.
6. **USART** — USART0 `0x40004800` (APB1 bit 18); UART1 `0x40004400` (APB1
   bit 17); UART2 `0x40011000` (APB2 bit 4). New-style CTL0/BAUD/STAT/RDATA/TDATA
   (UM §16.4) — **not** VF103 STAT/DATA @ USART0 `0x40013800`. CTL0 UEN is
   bit 0 (not bit 13). Same `Uart` methods; `Uart.rdata` is VF103 DATA /
   VW553 RDATA so TX and RX can be split.
7. **I2C** — I2C0 `0x40005400` / I2C1 `0x40005800` (APB1 bits 21/22). New-style
   CTL0/CTL1/TIMING/STAT/RDATA/TDATA (UM §17.4) — **not** VF103 STAT0/DATA /
   CKCFG (same base addresses, different registers). Factory returns
   **`I2cVw553`** with the same method names as `I2c` (different IP — no kind
   branch on the VF103 path). Default SCL=PA2 AF2 / SDA=PA3 AF2.
8. **SPI** — one SPI @ `0x40013000` (APB2 bit 12). Same CTL0/STAT/DATA as
   VF103 SPI0 — same `Spi` methods (TBE=bit 1, RBNE=bit 0). Soft NSS.
   Default SCK=PA5 AF4 / MISO=PA6 AF3 / MOSI=PA7 AF5.
9. **ADC** — one ADC @ `0x40012000` (APB2 bit 8). UM §12.5 CTL1 SWRCST **bit 30**,
   4-bit SAMPT, 12-bit DRES=00 — **not** VF103 ADC0 @ `0x40012400` / SWRCST
   bit 22. Factory returns **`AdcVw553`** with the same method names as `Adc`.
   GPIO analog (`CTL=11`), no AF. Default CH0=PA0. Channels 0..=8 = PAx;
   9=temp / 10=VREFINT (`TSVREN`).
10. **Core** — N307 (RV32IMAFDCPB). Examples stay polling; no ECLIC this tag.

Same `Pin` / `Pwm` / `Rc` / `Uart` / `Spi` methods as VF103 — only the factory
and register pointers differ. I2c is `I2cVw553` and Adc is `AdcVw553`
(different IP).

## Scope (`@v0.3.0` — Pin)

- `pin_out_vw553` / `pin_in_vw553` + host `*_test.kl`
- Example `examples/blink_pa8_vw553/` (default PA8; edit for the board)

## Scope (`@v0.4.0` — Pwm + Rc)

- `pwm_out_vw553(port, num, tim, ch, af, tim_clk_hz)` / `rc_out_vw553(...)`
- Host tests for timer bases / AFSEL layout (no factory MMIO)
- Examples `examples/pwm_pa0_vw553/` / `examples/rc_pa0_vw553/` (TIMER1_CH0
  PA0 AF1, IRC16M ≈ 16 MHz)
- `version()` → 3

## Scope (`@v0.5.0` — Uart)

- `uart_out_vw553(usart, tx_port, tx_num, tx_af, rx_port, rx_num, rx_af, usart_clk_hz, baud)`
- Host tests for USART bases / baud@16 MHz (no factory MMIO)
- Example `examples/uart_pa0_vw553/` (USART0 TX=PA0 AF0, RX=PA1 AF0,
  IRC16M ≈ 16 MHz, 115200 8N1)
- `version()` → 4

## Scope (`@v0.6.0` — I2c)

- `i2c_out_vw553(i2c, scl_port, scl_num, scl_af, sda_port, sda_num, sda_af, i2c_clk_hz, freq_hz)` → `I2cVw553`
- Host tests for I2C bases / TIMING / CTL1 encoding (no factory MMIO)
- Example `examples/i2c_pa2_vw553/` (I2C0 SCL=PA2 AF2, SDA=PA3 AF2,
  IRC16M ≈ 16 MHz, 100 kHz; external pull-ups)
- `version()` → 5

## Scope (`@v0.7.0` — Spi)

- `spi_out_vw553(spi, sck_*, miso_*, mosi_*, spi_clk_hz, baud_hz, mode)` → `Spi`
- Host tests for SPI base / baud@16 MHz (no factory MMIO)
- Example `examples/spi_pa5_vw553/` (SCK=PA5 AF4, MISO=PA6 AF3, MOSI=PA7 AF5,
  IRC16M ≈ 16 MHz, 1 MHz mode 0, soft CS=PA4)
- `version()` → 6

## Scope (`@v0.8.0` — Adc)

- `adc_out_vw553(port, num, channel)` → `AdcVw553`
- Host tests for ADC base / channel clamp / SAMPT layout (no factory MMIO)
- Example `examples/adc_pa0_vw553/` (CH0=PA0 analog, PWM fade on PA1
  TIMER1_CH1 AF1, IRC16M ≈ 16 MHz)
- `version()` → 7

## Out of scope (this tag)

- Wi‑Fi — [`gd32v_wifi`](https://github.com/klin-lang/gd32v_wifi) [`@v0.4.0`](https://github.com/klin-lang/gd32v_wifi/releases/tag/v0.4.0) [137](137-gd32v-wifi-sdk.md) (not this package; not `esp_wifi`)
- BLE — [`gd32v_ble`](https://github.com/klin-lang/gd32v_ble) [`@v0.4.0`](https://github.com/klin-lang/gd32v_ble/releases/tag/v0.4.0) [140](140-gd32v-ble-sdk.md) (not this package; not `esp_ble`)
- Board pack / `klin init` — [`gd32vw553h_eval`](https://github.com/klin-lang/gd32vw553h_eval) [`@v0.1.0`](https://github.com/klin-lang/gd32vw553h_eval/releases/tag/v0.1.0) [138](138-board-gd32vw553h-eval.md), [`gd32vw553h_start`](https://github.com/klin-lang/gd32vw553h_start) [`@v0.1.0`](https://github.com/klin-lang/gd32vw553h_start/releases/tag/v0.1.0) [139](139-board-gd32vw553h-start.md) (not this package)
- Full Nuclei / GigaDevice wireless SDK vendoring
- Combining with CH32V sources

## Usage

```klin
import "github/klin-lang/machine_gd32v" machine

fn main() {
    let led = machine.pin_out_vw553(machine.Port.A, 8)
    let pwm = machine.pwm_out_vw553(machine.Port.A, 0, 1, 1, 1, 16000000)
    let u = machine.uart_out_vw553(
        0,
        machine.Port.A, 0, 0,
        machine.Port.A, 1, 0,
        16000000,
        115200
    )
    led.toggle()
    pwm.duty_u16(32768)
    u.write_u8(10)
    let bus = machine.i2c_out_vw553(
        0,
        machine.Port.A, 2, 2,
        machine.Port.A, 3, 2,
        16000000,
        100000
    )
    let mut w: [1]u8
    w[0] = 0
    bus.writeto(0x50, w)
    let s = machine.spi_out_vw553(
        0,
        machine.Port.A, 5, 4,
        machine.Port.A, 6, 3,
        machine.Port.A, 7, 5,
        16000000,
        1000000,
        0
    )
    let _ = s.write_read_u8(0x9F)
    let adc = machine.adc_out_vw553(machine.Port.A, 0, 0)
    let raw = adc.read_u12()
}
```

Do **not** call `pin_out` / `pwm_out` / `rc_out` / `uart_out` / `i2c_out` / `spi_out` / `adc_out` (VF103) on a VW553.

```sh
klin get github/klin-lang/machine_gd32v@v0.8.0
```

## Links

- Package: https://github.com/klin-lang/machine_gd32v
- Tags: [v0.3.0](https://github.com/klin-lang/machine_gd32v/releases/tag/v0.3.0) (Pin),
  [v0.4.0](https://github.com/klin-lang/machine_gd32v/releases/tag/v0.4.0) (Pwm+Rc),
  [v0.5.0](https://github.com/klin-lang/machine_gd32v/releases/tag/v0.5.0) (Uart),
  [v0.6.0](https://github.com/klin-lang/machine_gd32v/releases/tag/v0.6.0) (I2c),
  [v0.7.0](https://github.com/klin-lang/machine_gd32v/releases/tag/v0.7.0) (Spi),
  [v0.8.0](https://github.com/klin-lang/machine_gd32v/releases/tag/v0.8.0) (Adc)
- VF103 MVP: [135](135-machine-gd32v.md)
- Catalog: [061](061-micropython-machine-api.md), targets [062](062-targets-esp-rp.md)
