# klin_shtc3

Klin chip driver for **Sensirion SHTC3** temperature/humidity over I2C.

Not Arduino, not in the Klin stdlib. The app owns the bus (`Wire` with
`write` / `read` / `write_read` / `delay_ms`). This package wakes the
sensor, runs a polling T+RH measurement (no clock stretch), checks
Sensirion CRC8, converts to millidegree C / milli-%RH, then sleeps.

Board glue for Waveshare ESP32-S3-RLCD-4.2 lives in
[`waveshare_esp32_s3_rlcd_42`](https://github.com/klin-lang/waveshare_esp32_s3_rlcd_42).

## Requirements

- [Klin](https://github.com/klin-lang/klin) compiler

## Install

```sh
klin get github/klin-lang/klin_shtc3@v0.1.0
```

Repo: https://github.com/klin-lang/klin_shtc3  
Local: `-I` this tree or a sibling `klin_shtc3/`.

```sh
klin test klin_shtc3
klin run -I. examples/host_smoke.kl
```

## API (`@v0.1.0`)

| Symbol | Meaning |
|---|---|
| `version(): i32` | `1` at `v0.1.0` |
| `addr7()` | `0x70` |
| `Wire` | `write` / `read` / `write_read` / `delay_ms` + `ctx` |
| `attach(wire)` | store wire (no bus init) |
| `(Dev) measure(out_temp_mC, out_hum_mRh)` | wake → meas `0x7866` → ~15 ms → read 6 → sleep |
| `crc8` / `temp_mC_from_raw` / `hum_mRh_from_raw` | helpers |
| `err_ok` / `err_bad_arg` / `err_io` / `err_crc` | `0` / `1` / `2` / `3` |

Temperature: `-45000 + (175000 * raw_t) / 65536` (m°C).  
Humidity: `(100000 * raw_rh) / 65536` (m%RH).  
CRC8: poly `0x31`, init `0xFF`.

### Wire

```klin
import klin_shtc3 sht

fn i2c_write(ctx: *mut u8, addr7: i32, data: *u8, len: i32): i32 { return 0 }
fn i2c_read(ctx: *mut u8, addr7: i32, buf: *mut u8, len: i32): i32 { return 0 }
fn i2c_wr(ctx: *mut u8, addr7: i32, w: *u8, wl: i32, r: *mut u8, rl: i32): i32 { return 0 }
fn wait_ms(ctx: *mut u8, ms: i32) { }

fn main() {
    let wire = sht.Wire{
        ctx: cast(*mut u8, 0),
        write: i2c_write,
        read: i2c_read,
        write_read: i2c_wr,
        delay_ms: wait_ms
    }
    let dev = sht.attach(wire)
    let mut t: i32 = 0
    let mut h: i32 = 0
    let e = dev.measure(&t, &h)
}
```

## Changelog

| Tag | Notes |
|---|---|
| `@v0.1.0` | Wire attach + measure (T/RH mC/mRh) + CRC8 |

## Layout

Directory `klin_shtc3/` is one module. `*_test.kl` stays out of `import`.

## License

MIT
