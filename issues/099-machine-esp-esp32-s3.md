# 099 — `machine_esp` ESP32-S3 (Pin…Adc twin factories)

**Status:** ✅ published `@v0.5.0` (Pin) / `@v0.6.0` (Pin…Adc) / `@v0.7.0` (Rmt TX)  
**Depends on:** [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** (emit C + ESP-IDF toolchain, same as C3) |
| Where does the code live? | External: [`klin-lang/machine_esp`](https://github.com/klin-lang/machine_esp) |
| Pattern | Twin factories like `machine_rp` `*_rp2350` — **no** shared `#ifdef` mega-driver |
| C3 | Unchanged: `pin_out` / `pwm_out` / … |
| S3 | Explicit: `pin_out_s3` / `pin_in_s3` / `pwm_out_s3` / `rc_out_s3` / `uart_out_s3` / `i2c_out_s3` / `spi_out_s3` / `adc_out_s3` / `rmt_tx_s3` |

## What changed vs C3 (MMIO, not ISA)

Peripheral bases stay in the `0x6000…` band. S3 needs different:

1. **GPIO matrix** — `SIG_GPIO_OUT=256`, OEN bit 10, IN_SEL bit 7 / 6-bit gpio  
2. **GPIO ≥ 32** — `OUT1` / `ENABLE1` / `IN1`  
3. **SYSTEM clock/reset** — `PERIP_CLK_EN0` `@ +0x18`, RST `@ +0x20`  
4. **Signal IDs** — UART0=12, LEDC base 73, I2C 89/90, FSPI 101+  
5. **ADC1 map** — CH0..9 → GPIO1..10  
6. **Examples** — `idf.py set-target esp32s3`

Xtensa vs RISC-V is handled by **ESP-IDF**, not Klin.

## Scope

| Tag | Contents |
|---|---|
| [`@v0.5.0`](https://github.com/klin-lang/machine_esp/releases/tag/v0.5.0) | `pin_out_s3` / `pin_in_s3` + `examples/blink_s3` (default GPIO2) |
| [`@v0.6.0`](https://github.com/klin-lang/machine_esp/releases/tag/v0.6.0) | Pwm/Rc/Uart/I2c/Spi/Adc `*_s3` + examples `*_s3` |
| [`@v0.7.0`](https://github.com/klin-lang/machine_esp/releases/tag/v0.7.0) | `rmt_tx_s3` (TX ch 0..=3, `put`/`start`/`wait_done`; no DMA/carrier) |

## Out of scope (this port)

- Wi‑Fi / BLE / `esp_wifi` in this package — Wi‑Fi → separate [`esp_wifi`](https://github.com/klin-lang/esp_wifi) ([101](101-esp-wifi-idf.md)); BLE / USB OTG / camera → [103](103-later-tracks-ble-usb-camera-lcd.md)
- Freestanding (no IDF)
- Classic ESP32 / C6
- Waveshare ESP32-S3-Pico board pack — ✅ [100](100-board-waveshare-esp32-s3-pico.md) `@v0.3.0`
- `klin init waveshare-esp32-s3-pico` — ✅ ([075](075-board-pack-init-host.md); pack [100](100-board-waveshare-esp32-s3-pico.md))

## Usage

```klin
import "github/klin-lang/machine_esp" machine

let led = machine.pin_out_s3(2)
let pwm = machine.pwm_out_s3(2, 0, 0, 80000000)
let u = machine.uart_out_s3(0, 17, 18, 80000000, 115200)
let adc = machine.adc_out_s3(1, 0) // CH0 → GPIO1
let rmt = machine.rmt_tx_s3(21, 0, 80000000) // tick = APB/8
```

```sh
klin get github/klin-lang/machine_esp@v0.7.0
```

## Links

- Repo: https://github.com/klin-lang/machine_esp  
- PR: https://github.com/klin-lang/machine_esp/pull/6 (Pin…Adc), [#7](https://github.com/klin-lang/machine_esp/pull/7) (Rmt)  
- Catalog: [061](061-micropython-machine-api.md), targets [062](062-targets-esp-rp.md)
