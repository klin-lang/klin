# Arduino boards and Klin

**Yes** — Klin can program classic Arduino-class boards. It is **not** the
Arduino IDE / Wiring API: Klin emits **C**, then you link with the usual AVR
toolchain (`avr-gcc`, etc.).

## Classic AVR Arduino

Package: [`machine_avr`](https://github.com/klin-lang/machine_avr) `@v0.2.0`  
Catalog: [061](../issues/061-micropython-machine-api.md)

| Board | Chip | Status |
|---|---|---|
| **Uno** (and 328P clones) | ATmega328P | Pin…Adc + Pwm / Uart / I2c / Spi ✅ |
| **Mega** | ATmega2560 | Pin ✅ (`pin_out_2560`); bus factories later |

Examples in the package: `blink_uno` (D13 = PB5), `blink_mega` (D13 = PB7).

```sh
klin get github/klin-lang/machine_avr@v0.2.0
```

## Other boards sold as “Arduino”

Many newer boards reuse the Arduino **form factor** or brand but not megaAVR:

| Board family | Klin package |
|---|---|
| ESP32 / ESP32-C3 / ESP32-S3 | [`machine_esp`](https://github.com/klin-lang/machine_esp) (+ [`esp_wifi`](https://github.com/klin-lang/esp_wifi) / [`esp_eth`](https://github.com/klin-lang/esp_eth) / [`esp_ble`](https://github.com/klin-lang/esp_ble) for radio) |
| RP2040 / RP2350 | [`machine_rp`](https://github.com/klin-lang/machine_rp) |

Those are **not** `machine_avr`.

## Out of scope (for now)

- Arduino libraries (`.ino`, Wiring, `Servo.h`, …) as a Klin layer  
- ATmega2560 Pwm…Adc factories (Pin only today)  
- tinyAVR / AVR Dx — later in `machine_avr`

## Links

- Targets overview: [062](../issues/062-targets-esp-rp.md)  
- `machine` catalog: [061](../issues/061-micropython-machine-api.md)  
- AVR package: https://github.com/klin-lang/machine_avr
