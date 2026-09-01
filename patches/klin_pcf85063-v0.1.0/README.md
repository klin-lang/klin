# klin_pcf85063

Klin chip driver for **NXP PCF85063** RTC over I2C.

Not Arduino, not in the Klin stdlib. The app owns the bus (`Wire`).
This package reads/writes the SC..YR datetime block (regs `0x04`..`0x0A`)
with BCD encode/decode.

Board glue for Waveshare ESP32-S3-RLCD-4.2 lives in
[`waveshare_esp32_s3_rlcd_42`](https://github.com/klin-lang/waveshare_esp32_s3_rlcd_42).

## Requirements

- [Klin](https://github.com/klin-lang/klin) compiler

## Install

```sh
klin get github/klin-lang/klin_pcf85063@v0.1.0
```

Repo: https://github.com/klin-lang/klin_pcf85063  
Local: `-I` this tree or a sibling `klin_pcf85063/`.

```sh
klin test klin_pcf85063
klin run -I. examples/host_smoke.kl
```

## API (`@v0.1.0`)

| Symbol | Meaning |
|---|---|
| `version(): i32` | `1` at `v0.1.0` |
| `addr7()` | `0x51` |
| `Wire` | `write` / `read` / `write_read` / `delay_ms` + `ctx` |
| `attach(wire)` | store wire (no bus init) |
| `(Dev) read_time(sec..year *mut i32)` | read 7 BCD regs |
| `(Dev) set_time(sec..year i32)` | write 7 BCD regs |
| `bcd_to_bin` / `bin_to_bcd` | helpers |
| `err_ok` / `err_bad_arg` / `err_io` | `0` / `1` / `2` |

Masks on read: sec/`min` `&0x7F`, hour/`day` `&0x3F`, wday `&0x07`, month `&0x1F`.  
Year is **0..99** (register years). Month **1..12**. Wday **0..6**.

## Changelog

| Tag | Notes |
|---|---|
| `@v0.1.0` | Wire attach + read_time / set_time |

## Layout

Directory `klin_pcf85063/` is one module. `*_test.kl` stays out of `import`.

## License

MIT
