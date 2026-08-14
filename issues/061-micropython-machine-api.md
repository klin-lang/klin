# 061 — MicroPython `machine`-style API (PWM, UART, …)

**Status:** ✅ decided (external package; not Klin stdlib)
**Depends on:** [010](010-bare-metal.md); nice to have [031](031-hal-libraries.md), [027](027-svd-ergonomic-api.md), [053](053-device-board-assets.md)
**Packages:** [`machine_stm32`](https://github.com/klin-lang/machine_stm32) (`Pin`…`Adc` `@v0.5.0`), [`machine_rp`](https://github.com/klin-lang/machine_rp) (`Pin`…`Adc`+**Pio**+**Dma**+**UsbCdc** `@v0.11.0`), [`machine_esp`](https://github.com/klin-lang/machine_esp) (C3 + **S3** `*_s3` Pin…Adc+**Rmt** `@v0.7.0`; [099](099-machine-esp-esp32-s3.md)), [`machine_stm8`](https://github.com/klin-lang/machine_stm8) (`Pin`…`Adc` `@v0.2.0`), [`machine_avr`](https://github.com/klin-lang/machine_avr) (`Pin` 328P+2560; `Pwm`…`Adc` **328P** `@v0.2.0`), [`machine_xmega`](https://github.com/klin-lang/machine_xmega) (`Pin`…`Dac` `@v0.2.0`), [`machine_pic16`](https://github.com/klin-lang/machine_pic16) (`Pin`…`Dac` `@v0.2.0`), [`machine_ch32v`](https://github.com/klin-lang/machine_ch32v) (`Pin`…`Adc` `@v0.1.0`; [086](086-machine-ch32v.md)), [`machine_gd32v`](https://github.com/klin-lang/machine_gd32v) (`Pin`…`Adc` `@v0.2.0`; [087](087-machine-gd32v.md))

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** for the library itself |
| Where does the code live? | External repos (not `stdlib/`): **`machine_stm32`**, **`machine_rp`**, **`machine_esp`**, **`machine_stm8`**, **`machine_xmega`**, **`machine_avr`**, **`machine_pic16`**, **`machine_ch32v`**, **`machine_gd32v`** |
| STM32? | **Yes** — [`machine_stm32`](https://github.com/klin-lang/machine_stm32) (`Pin` + `Pwm` + `Rc` + `Uart` + `I2c` + `Spi` + `Adc` `@v0.5.0`; F411/F401-class — **no HW DAC**); board [`nucleo_f411re`](https://github.com/klin-lang/nucleo_f411re) `@v0.1.3` → [096](096-board-nucleo-f411re.md) |
| RP2040 / RP2350? | **`machine_rp`** — Pin+Pwm+Rc+Uart+I2c+Spi+Adc+**Pio**+**Dma**+**UsbCdc** ✅ `@v0.11.0` (**no HW DAC**; UsbCdc RP2350 poll; Pio `out_pins`/TX DMA); ([062](062-targets-esp-rp.md)); boards [`waveshare_rp2350_lcd_096`](https://github.com/klin-lang/waveshare_rp2350_lcd_096) `@v0.13.0` → [095](095-board-waveshare-rp2350-lcd-096.md), [`adafruit_rp2040_can_feather`](https://github.com/klin-lang/adafruit_rp2040_can_feather) `@v0.1.0` (MCP25625 SPI CAN) → [098](098-board-adafruit-rp2040-can-feather.md) |
| ESP32-C3 / **S3**? | **`machine_esp`** — C3 `pin_out`…`adc_out` ✅; S3 twin `*_s3` Pin…Adc+**Rmt** ✅ `@v0.7.0` ([099](099-machine-esp-esp32-s3.md); **no HW DAC** API); board [`waveshare_esp32_s3_pico`](https://github.com/klin-lang/waveshare_esp32_s3_pico) `@v0.3.0` (WS2812 via RMT) → [100](100-board-waveshare-esp32-s3-pico.md); minimal ESP-IDF boot; **Wi‑Fi** → separate [`esp_wifi`](https://github.com/klin-lang/esp_wifi) `@v0.1.1` ([101](101-esp-wifi-idf.md), not in `machine_*`); **ETH** → [`esp_eth`](https://github.com/klin-lang/esp_eth) `@v0.1.2` [102](102-esp-eth-idf.md); **BLE** → [`esp_ble`](https://github.com/klin-lang/esp_ble) `@v0.9.0` [106](106-esp-ble-idf.md); freestanding / classic / C6 / **P4** later ([062](062-targets-esp-rp.md)) |
| STM8? | **`machine_stm8`** — Pin+Pwm+Rc+Uart+I2c+Spi+Adc ✅ `@v0.2.0` (STM8S103/S003; **no DAC**); ([062](062-targets-esp-rp.md)) |
| ATxmega? | **`machine_xmega`** — Pin+Pwm+Rc+Uart+I2c+Spi+Adc+**Dac** ✅ `@v0.2.0` (ATxmega128A1U-class; DACB) |
| megaAVR (Arduino Uno/Mega)? | **`machine_avr`** — Pin ✅ 328P+2560; **Pwm…Adc** ✅ **328P only** `@v0.2.0` (**no DAC**; 2560 bus factories later). Other Arduino SKUs (Leonardo / Uno R4 / Due / Giga / Portenta) → [107](107-later-tracks-arduino-boards.md). |
| PIC16? | **`machine_pic16`** — Pin+Pwm+Rc+Uart+I2c+Spi+Adc+**Dac** ✅ `@v0.2.0` (PIC16F18855; PPS explicit; DAC1 5-bit HW) |
| CH32V003 (QingKe RISC-V)? | **`machine_ch32v`** — Pin…Adc ✅ `@v0.1.0` ([086](086-machine-ch32v.md)); **10-bit** ADC |
| GD32VF103 (Nuclei RISC-V)? | **`machine_gd32v`** — Pin…Adc ✅ `@v0.2.0` ([087](087-machine-gd32v.md)); **12-bit** ADC |
| Other PIC? | Separate ports if/when needed — not one library for all MCUs |
| DAC? | Only where the silicon has it — **yes** on ATxmega (DACB) and PIC16F18855 (DAC1); **not** on F411/F401, RP2040/2350, ESP32-C3/S3 (no `Dac` API), STM8S, megaAVR 328P/2560, CH32V003, GD32VF103. F407-class / classic ESP32 later if needed. |
| PIO? | Only RP2040/RP2350 silicon — **yes** in [`machine_rp`](https://github.com/klin-lang/machine_rp) `@v0.8.0`+ (sideset/shift/frac); **not** on stm32/esp/stm8/avr/xmega/pic16/ch32v/gd32v (no fake PIO). |
| DMA? | Only RP2040/RP2350 — **yes** in [`machine_rp`](https://github.com/klin-lang/machine_rp) `@v0.9.0` (`dma_out` / `write_dma*`); **not** on other `machine_*` ports. |
| USB CDC? | RP2350 first — **yes** in [`machine_rp`](https://github.com/klin-lang/machine_rp) `@v0.10.0` (`usb_cdc_out_rp2350` poll ACM); board Type-C console → [095](095-board-waveshare-rp2350-lcd-096.md); RP2040 later. |
| Approach | **C** (thin Klin package over explicit MMIO) — not A, not full vendor HAL as the API |

Chosen over A/B: MicroPython-like **shape** (`Pin`, later `Pwm` / `Uart`), with no GC, no hidden heap, no hidden clock magic. Clock / startup / linker stay in the app (board pack later: [074](074-board-ioc-klin-mod.md), [075](075-board-pack-init-host.md)).

### Import

Repo / module name uses underscore (valid Klin identifier), same pattern as `osa` / `eventloop`:

```klin
import "github/klin-lang/machine_stm32" machine

fn main() {
    let led = machine.pin_out(machine.Port.A, 5)
    led.toggle()
}
```

```sh
klin get github/klin-lang/machine_stm32@v0.5.0
```

### Pwm shape (shared convention, not one runtime)

Same *method names* across `machine_*` ports; **separate MMIO** per MCU
(no shared `machine` package, no `#ifdef` mega-driver):

| Piece | Role |
|---|---|
| `pwm_out(…)` | factory — chip-specific args OK |
| `freq(hz)` | frequency in Hz |
| `duty_u16(d)` | duty `0..=65535` (MicroPython-style) |
| `deinit()` | stop this PWM (explicit) |

### Rc shape (servo / RC pulse — ports that have Pwm)

| Piece | Role |
|---|---|
| `rc_out(…, freq_hz, us_min, us_max)` | factory — same HW args as `pwm_out` + frame/pulse range |
| `out(pos, k)` | `pos` `0..=100_000`, `k` trim µs (−1000..=1000), silent clamp |
| `out_f32(pos, k)` | `pos` `0.0..=1.0` (1.0 ≡ 100_000) |
| `pulse_us(us)` | raw pulse width |
| `deinit()` | stop underlying PWM |

### Uart shape (shared convention)

| Piece | Role |
|---|---|
| `uart_out(…, usart_clk_hz, baud)` | factory — chip-specific instance/pins/AF OK |
| `write_u8(b)` / `write(buf)` | blocking TX (`[]u8`) |
| `read_u8()` | blocking RX (0..=255) |
| `try_read_u8()` | non-blocking RX (−1 if empty) |
| `any()` | RXNE / byte waiting |
| `deinit()` | disable USART (explicit) |

### I2c / Spi / Adc shape (shared convention)

| Piece | Role |
|---|---|
| `i2c_out(…, i2c_clk_hz, freq_hz)` | I²C controller — chip-specific instance/pins/AF |
| `writeto` / `readfrom_into` / `write_readfrom_into` | blocking; caller buffers (`[]u8`, no heap) |
| `spi_out(…, spi_clk_hz, baud_hz, mode)` | SPI master — soft NSS; CS is a separate `Pin` |
| `write_read_u8` / `write` / `readinto` / `write_readinto` | full-duplex / fill buffer |
| `adc_out(…)` | ADC — stm32/stm8/avr/xmega/pic16 `(port, num, channel)`; rp/esp `(gpio, channel)` |
| `read_u12` / `read_u16` | raw (12-bit `0..=4095` on stm32/rp/esp/xmega; **10-bit** `0..=1023` on stm8/avr/pic16) / scaled `0..=65535` |
| `dac_out(…)` / `write_u12` | only where HW exists — xmega DACB (12-bit); pic16 DAC1 (**5-bit** HW, `write_u12` scales) |
| `pio_out(…)` / `load` / `active` / `put_u32` | only where HW exists — **RP** PIO SM; raw 16-bit program words (`[]i32`); no assembler |

`machine_stm32` `@v0.5.0`:

```klin
// PA5 = TIM2_CH1 AF1; tim_clk_hz explicit (HSI 16 MHz at reset)
let led = machine.pwm_out(machine.Port.A, 5, 2, 1, 1, 16000000)
led.freq(1000)
led.duty_u16(32768)

let servo = machine.rc_out(machine.Port.A, 5, 2, 1, 1, 16000000, 50, 1000, 2000)
servo.out(50000, 0)
servo.out_f32(0.25, 0)

// Nucleo VCP: USART2 PA2/PA3 AF7
let u = machine.uart_out(
    2,
    machine.Port.A, 2, 7,
    machine.Port.A, 3, 7,
    16000000,
    115200
)
u.write_u8(65)

// I2C1 PB8/PB9 AF4; SPI2 PB13/14/15 AF5; ADC1 PA0 CH0
let bus = machine.i2c_out(1, machine.Port.B, 8, 4, machine.Port.B, 9, 4, 16000000, 100000)
let s = machine.spi_out(2, machine.Port.B, 13, 5, machine.Port.B, 14, 5, machine.Port.B, 15, 5, 16000000, 1000000, 0)
let adc = machine.adc_out(machine.Port.A, 0, 0)
let v = adc.read_u16()
```

Examples: [`pwm_f411`](https://github.com/klin-lang/machine_stm32/tree/main/examples/pwm_f411),
[`rc_f411`](https://github.com/klin-lang/machine_stm32/tree/main/examples/rc_f411),
[`uart_f411`](https://github.com/klin-lang/machine_stm32/tree/main/examples/uart_f411),
[`i2c_f411`](https://github.com/klin-lang/machine_stm32/tree/main/examples/i2c_f411),
[`spi_f411`](https://github.com/klin-lang/machine_stm32/tree/main/examples/spi_f411),
[`adc_f411`](https://github.com/klin-lang/machine_stm32/tree/main/examples/adc_f411),
[`machine_rp/examples/pwm_pico`](https://github.com/klin-lang/machine_rp/tree/main/examples/pwm_pico),
[`rc_pico`](https://github.com/klin-lang/machine_rp/tree/main/examples/rc_pico),
[`uart_pico`](https://github.com/klin-lang/machine_rp/tree/main/examples/uart_pico),
[`i2c_pico`](https://github.com/klin-lang/machine_rp/tree/main/examples/i2c_pico),
[`spi_pico`](https://github.com/klin-lang/machine_rp/tree/main/examples/spi_pico),
[`adc_pico`](https://github.com/klin-lang/machine_rp/tree/main/examples/adc_pico),
[`pio_blink_pico`](https://github.com/klin-lang/machine_rp/tree/main/examples/pio_blink_pico),
[`machine_esp/examples/pwm_c3`](https://github.com/klin-lang/machine_esp/tree/main/examples/pwm_c3),
[`rc_c3`](https://github.com/klin-lang/machine_esp/tree/main/examples/rc_c3),
[`blink_s3`](https://github.com/klin-lang/machine_esp/tree/main/examples/blink_s3) / [`pwm_s3`](https://github.com/klin-lang/machine_esp/tree/main/examples/pwm_s3) (S3 → [099](099-machine-esp-esp32-s3.md)),
[`waveshare_esp32_s3_pico/examples/blink`](https://github.com/klin-lang/waveshare_esp32_s3_pico/tree/main/examples/blink) / [`rgb`](https://github.com/klin-lang/waveshare_esp32_s3_pico/tree/main/examples/rgb) / [`uart`](https://github.com/klin-lang/waveshare_esp32_s3_pico/tree/main/examples/uart) / [`i2c`](https://github.com/klin-lang/waveshare_esp32_s3_pico/tree/main/examples/i2c) / [`spi`](https://github.com/klin-lang/waveshare_esp32_s3_pico/tree/main/examples/spi) / [`adc`](https://github.com/klin-lang/waveshare_esp32_s3_pico/tree/main/examples/adc) / [`pwm`](https://github.com/klin-lang/waveshare_esp32_s3_pico/tree/main/examples/pwm) ([100](100-board-waveshare-esp32-s3-pico.md)),
[`machine_stm8/examples/rc_pd4`](https://github.com/klin-lang/machine_stm8/tree/main/examples/rc_pd4).

`machine_rp` `@v0.9.0`:

```klin
let led = machine.pwm_out(25, 6000000)
let u = machine.uart_out(0, 0, 1, 125000000, 115200)
let bus = machine.i2c_out(0, 4, 5, 125000000, 100000)
let s = machine.spi_out(0, 18, 19, 16, 125000000, 1000000, 0)
let adc = machine.adc_out(26, 0)
let sm = machine.pio_out(0, 0)  // PIO0 SM0; RP2350: pio_out_rp2350 (+ PIO2)
sm.gpio_init(25)
sm.config_sideset_pins(25, 1)
sm.config_out_shift(0, 1, 24)
sm.config_fifo_join_tx()
let d = machine.dma_out(0)
s.write_dma(d, buf, machine.dma_dreq_spi0_tx())
// load raw encodings (pio_encode_*), config_wrap / config_clkdiv_frac, active(1)
// RP2350: *_rp2350 twins (+ dma_out_rp2350 / dma_dreq_spi*_tx_rp2350)
```

`machine_esp` `@v0.7.0` (C3 factories; S3 twins + Rmt — [099](099-machine-esp-esp32-s3.md)):

```klin
let led = machine.pwm_out(8, 0, 0, 80000000)
let u = machine.uart_out(0, 21, 20, 80000000, 115200)
let bus = machine.i2c_out(0, 8, 9, 40000000, 100000)  // XTAL clock for I2C
let s = machine.spi_out(2, 6, 7, 2, 80000000, 1000000, 0)
let adc = machine.adc_out(0, 0)
// ESP32-S3:
let led_s3 = machine.pin_out_s3(2)
let pwm_s3 = machine.pwm_out_s3(2, 0, 0, 80000000)
let u_s3 = machine.uart_out_s3(0, 17, 18, 80000000, 115200)
let adc_s3 = machine.adc_out_s3(1, 0) // CH0 → GPIO1
let rmt_s3 = machine.rmt_tx_s3(21, 0, 80000000) // WS2812-style; tick = APB/8
```

`machine_stm8` `@v0.2.0` (UART1 PD5/PD6; ADC 10-bit — `read_u12` name kept for parity):

```klin
let led = machine.pwm_out(machine.Port.D, 4, 1, 2000000)
let u = machine.uart_out(1, machine.Port.D, 5, machine.Port.D, 6, 2000000, 115200)
let adc = machine.adc_out(machine.Port.D, 2, 3)
```

`machine_avr` `@v0.2.0` (**ATmega328P** USART0 / TWI / SPI / ADC10; **no DAC**; 2560 = Pin only):

```klin
let pwm = machine.pwm_out(machine.Port.B, 1, 1, 1, 16000000) // Uno PB1 OC1A
let u = machine.uart_out(machine.Port.D, 1, machine.Port.D, 0, 16000000, 9600)
let adc = machine.adc_out(machine.Port.C, 0, 0)
```

`machine_xmega` `@v0.2.0` (TCC0 / USARTC0 / TWIC / SPIC / ADCA / **DACB**; `remap` explicit):

```klin
let pwm = machine.pwm_out(machine.Port.C, 0, 0, 1, 0, 32000000)
let u = machine.uart_out(machine.Port.C, 3, machine.Port.C, 2, 0, 32000000, 115200)
let dac = machine.dac_out(machine.Port.B, 2, 0)
dac.write_u12(2048)
```

`machine_pic16` `@v0.2.0` (CCP1+TMR2 / EUSART / MSSP / ADC10 / **DAC1**; PPS explicit):

```klin
let pwm = machine.pwm_out(machine.Port.C, 0, 1, machine.pps_ccp1(), 32000000)
let u = machine.uart_out(machine.Port.C, 0, machine.pps_tx(), machine.Port.C, 1, 32000000, 115200)
let dac = machine.dac_out(machine.Port.A, 2, 0)
dac.write_u12(2048)
```

### Roadmap

**`machine_stm32`**

1. **Pin** + blink (Nucleo-F411 PA5) — ✅  
2. **PWM** (TIM2–TIM5, explicit tim/ch/af/clk) — ✅ `@v0.2.0`  
3. **Rc** (servo / RC pulse on Pwm) — ✅ `@v0.3.0` (`rc_f411`)  
4. **Uart** (USART1/2/6, explicit clk/baud) — ✅ `@v0.4.0` (`uart_f411`)  
5. **I2c** / **Spi** / **Adc** — ✅ `@v0.5.0` (`i2c_f411`, `spi_f411`, `adc_f411`)  
6. DAC only if/when targeting a chip that has it (not F411)  
7. No PIO (STM32 silicon — not RP-style PIO)  

**`machine_rp`**

1. **Pin** + blink RP2040 / RP2350 — ✅  
2. **PWM** / **Rc** — ✅ `@v0.4.0` / `@v0.5.0`  
3. **Uart** / **I2c** / **Spi** / **Adc** — ✅ `@v0.6.0` (`uart_pico`, `i2c_pico`, `spi_pico`, `adc_pico`)  
4. **Pio** — ✅ `@v0.7.0` / `@v0.8.0` (`pio_blink_pico`; sideset/shift/frac for WS2812-style)  
5. **Dma** — ✅ `@v0.9.0` (`dma_out` / `Spi.write_dma` / `write_dma_repeat2`; board LCD DMA→SPI1 → [095](095-board-waveshare-rp2350-lcd-096.md))  
6. **UsbCdc** — ✅ `@v0.10.0` (RP2350 poll ACM + `@[link]` `usb_cdc_rp.c`; board `usb_console` → [095](095-board-waveshare-rp2350-lcd-096.md); RP2040 later)  
7. **Pio TX SPI helpers** — ✅ `@v0.11.0` (`out_pins` / `put_u8` / `wait_tx_stall` / `write_dma*` / `dma_dreq_pio_tx`; board PIO-as-SPI LCD → [095](095-board-waveshare-rp2350-lcd-096.md))  
8. No DAC (silicon)  

**`machine_esp`**

1. **Pin** + blink ESP32-C3 — ✅  
2. **PWM** / **Rc** (LEDC) — ✅ `@v0.2.0` / `@v0.3.0`  
3. **Uart** / **I2c** / **Spi** / **Adc** (C3) — ✅ `@v0.4.0`  
4. **ESP32-S3** twin factories Pin…Adc (`*_s3`) — ✅ `@v0.5.0` / `@v0.6.0` ([099](099-machine-esp-esp32-s3.md))  
5. **Rmt** TX S3 (`rmt_tx_s3`) — ✅ `@v0.7.0` (board WS2812 RMT → [100](100-board-waveshare-esp32-s3-pico.md))  
6. Board Waveshare ESP32-S3-Pico — ✅ `@v0.3.0` (RMT rgb + uart/i2c/spi/adc/pwm) ([100](100-board-waveshare-esp32-s3-pico.md))  
7. **Wi‑Fi** — ✅ separate package [`esp_wifi`](https://github.com/klin-lang/esp_wifi) `@v0.1.1` (STA thin IDF; DHCP default + optional static; not in `machine_esp`) → [101](101-esp-wifi-idf.md)  
8. **Ethernet** — ✅ [`esp_eth`](https://github.com/klin-lang/esp_eth) `@v0.1.2` (W5500; not in `machine_esp`) → [102](102-esp-eth-idf.md)  
9. **BLE** — ✅ [`esp_ble`](https://github.com/klin-lang/esp_ble) `@v0.9.0` (advertise + GATT server/client + scan/connect + bond + UUID16/128 + multi-svc + passkey + privacy/RPA; not in `machine_esp`) → [106](106-esp-ble-idf.md)  
10. No DAC / no PIO API; freestanding / classic ESP32 / C6 / **ESP32-P4** later ([062](062-targets-esp-rp.md); P4 also preferred RMII host for [102](102-esp-eth-idf.md))  

**`machine_stm8`**

1. **Pin** / **Pwm** / **Rc** — ✅ `@v0.1.0`  
2. **Uart** / **I2c** / **Spi** / **Adc** — ✅ `@v0.2.0`  
3. No DAC / no PIO on STM8S; SDCC link / STM8L later  

**`machine_xmega`** (formerly `machine_atmel`)

1. **Pin** + blink ATxmega (XMEGA-A1U Xplained PORTR.0) — ✅ `@v0.1.1` (`blink_xmega`)  
2. **Pwm** / **Rc** / **Uart** / **I2c** / **Spi** / **Adc** / **Dac** — ✅ `@v0.2.0`  

**`machine_avr`**

1. **Pin** + blink ATmega328P (Arduino Uno D13 = PB5) — ✅ `@v0.1.0` (`blink_uno`)  
2. **Pin** + blink ATmega2560 (Arduino Mega D13 = PB7) — ✅ `@v0.1.0` (`blink_mega`, `pin_out_2560`)  
3. **Pwm** / **Rc** / **Uart** / **I2c** / **Spi** / **Adc** — ✅ `@v0.2.0` (**328P MMIO**; no DAC; no PIO)  
4. ATmega2560 bus factories / **ATmega32U4 (Leonardo)** / tinyAVR / AVR Dx — later → Arduino backlog [107](107-later-tracks-arduino-boards.md)  


**`machine_pic16`**

1. **Pin** + blink PIC16F18855 (Curiosity Nano RA0) — ✅ `@v0.1.0` (`blink_curiosity`)  
2. **Pwm** / **Rc** / **Uart** / **I2c** / **Spi** / **Adc** / **Dac** — ✅ `@v0.2.0` (PPS explicit)  
3. Classic F877A / PIC18 — later  


Other MCU families = other repos — not “one machine for everything”.

## Context

[MicroPython](https://docs.micropython.org/en/latest/library/machine.html)
provides **ready-made peripheral classes** in the `machine` module — same API shape on
many ports (STM32, RP2, ESP, …). Programmer calls PWM/UART without manual
MMIO or CubeMX.

Klin today: SVD / registers ([011](011-svd.md) / [027](027-svd-ergonomic-api.md))
or vendor HAL via FFI ([031](031-hal-libraries.md)). No
“like `machine.PWM`” layer in stdlib.

This issue = **inspiration catalog + decision** whether Klin wants a thin, explicit
board/chip API (no hidden allocation / magic), not a MicroPython port.

## What MicroPython has in `machine` (off-the-shelf)

Source: `machine` documentation (ports differ in completeness).

### Peripheral classes (core)

| Class | Meaning |
|---|---|
| `Pin` | GPIO in/out/open-drain, pull, irq |
| `Signal` | Pin + inverted logic (active low) |
| `PWM` | frequency + duty (`duty_u16` / `duty_ns`) |
| `ADC` / `ADCBlock` | analog measurement |
| `DAC` | analog output (when MCU has it) |
| `UART` | serial duplex (baud, tx/rx, read/write) |
| `SPI` / `SoftSPI` | SPI (HW vs bit-bang) |
| `I2C` / `SoftI2C` / `I2CTarget` | I²C controller / target |
| `I2S` | audio bus |
| `CAN` | Controller Area Network |
| `Timer` | hardware timers / callbacks |
| `Counter` / `Encoder` | pulse counting / quadrature |
| `RTC` | real-time clock → also [043](043-rtc.md) |
| `WDT` | watchdog |
| `SD` / `SDCard` | SD card (port-specific) |
| `USBDevice` | USB device (newer ports) |

### “Board / CPU” functions (selected)

`reset`, `soft_reset`, `freq`, `idle`, `sleep` / `lightsleep` /
`deepsleep`, `disable_irq` / `enable_irq`, `time_pulse_us`, `bitstream`, …
(set depends on port).

### Outside `machine`, but “ready” on embedded

- `time` / `utime` — sleep, ticks  
- `network` — Wi‑Fi/Ethernet (ESP etc.) — Klin: [`esp_wifi`](https://github.com/klin-lang/esp_wifi) STA → [101](101-esp-wifi-idf.md); [`esp_eth`](https://github.com/klin-lang/esp_eth) W5500 → [102](102-esp-eth-idf.md)  
- `bluetooth` — Klin: [`esp_ble`](https://github.com/klin-lang/esp_ble) NimBLE advertise + GATT + scan + bond + UUID16/128 + multi-svc + passkey + privacy/RPA → [106](106-esp-ble-idf.md)  

- `esp*`, `rp2`, `stm` — port-specific  
- `uos` / VFS — files on flash/SD  

For Klin most important initially: **Pin, PWM, UART, I2C, SPI, ADC,
Timer, WDT** (what people expect from “like MicroPython”).

## UX example (MicroPython)

```python
from machine import Pin, PWM, UART

led = Pin(2, Pin.OUT)
pwm = PWM(Pin(15), freq=1000, duty_u16=32768)
uart = UART(1, baudrate=115200, tx=Pin(4), rx=Pin(5))
uart.write(b"hi\n")
```

## What it means for Klin

| Approach | Meaning |
|---|---|
| **A. SVD + examples only** | status quo; zero “machine” |
| **B. FFI to vendor HAL/LL** | [031](031-hal-libraries.md) — C alongside, thin `@[cimport]` |
| **C. Thin Klin `machine` package (external)** | Pin/PWM/UART… as explicit API over MMIO; **no** GC, no hidden heap; init/clock still explicit (startup / board pack [053](053-device-board-assets.md)) — **chosen**; lives outside the compiler repo |

Preference aligned with overarching rule: if C, then **explicit** clock tuning
/ pin mux / errors; do not promise full portability like µPython
(different MCUs = different PWM/timer limits).

## Out of scope

- Interpreter / GC / dynamic types like µPython  
- Full parity of all ports and classes (`I2S`, `USBDevice` in MVP); on-chip
  `Can` only where silicon has it — external SPI CAN (MCP2515/MCP25625) is a
  **board pack** ([098](098-board-adafruit-rp2040-can-feather.md)), not
  `machine_rp.Can`
- Hidden callbacks with allocation in IRQ  
- Priority relative to language core  
- Putting `machine` into Klin `stdlib/`

## Links

- Packages: https://github.com/klin-lang/machine_stm32 , https://github.com/klin-lang/machine_rp , https://github.com/klin-lang/machine_esp , https://github.com/klin-lang/machine_stm8 , https://github.com/klin-lang/machine_xmega , https://github.com/klin-lang/machine_avr , https://github.com/klin-lang/machine_pic16  






- MicroPython `machine`: https://docs.micropython.org/en/latest/library/machine.html  
- Klin vendor HAL: [031](031-hal-libraries.md)  
- Embedded project layout: [054](054-embedded-project-layout.md)  
- Other MCU targets: [062](062-targets-esp-rp.md)  
