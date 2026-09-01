# klin_st7305

Klin chip driver for **ST7305** reflective LCD over 4-wire SPI.

Not Arduino, not in the Klin stdlib. The app owns the bus (`machine_*`
`Spi` + `Pin`, ESP-IDF hooks, or any other C/Klin `Wire`). This package
sends the Waveshare-style init sequence and packs a **caller-owned**
monochrome framebuffer (400×300 landscape → **15000** bytes).

Default geometry matches **Waveshare ESP32-S3-RLCD-4.2**. Board glue
(pins, SPI bring-up, battery ADC) stays in
[`waveshare_esp32_s3_rlcd_42`](https://github.com/klin-lang/waveshare_esp32_s3_rlcd_42).

## Requirements

- [Klin](https://github.com/klin-lang/klin) compiler

## Install

```sh
klin get github/klin-lang/klin_st7305@v0.1.0
```

Repo: https://github.com/klin-lang/klin_st7305  
Local: `-I` this tree or a sibling `klin_st7305/`.

```sh
klin test klin_st7305
klin run -I. examples/host_smoke.kl
```

## API (`@v0.1.0`)

| Symbol | Meaning |
|---|---|
| `version(): i32` | `1` at `v0.1.0` |
| `width` / `height` / `fb_bytes` | 400 / 300 / 15000 |
| `Wire` | `cmd` / `data` / `data_n` / `delay_ms` / `rst` + `ctx` |
| `attach(wire)` | hardware reset + Waveshare init |
| `bound(wire)` | wrap wire without re-init |
| `clear` / `fill_black` / `set_pixel` / `rect` | caller `[]u8` FB |
| `(Lcd) flush(fb)` | CASET/RASET + RAMWR + bulk `data_n` |

White = bit **1** (`clear` → `0xFF`); black = bit **0**.

### Wire

```klin
import klin_st7305 lcd

fn spi_cmd(ctx: *mut u8, b: i32) { }
fn spi_data(ctx: *mut u8, b: i32) { }
fn spi_data_n(ctx: *mut u8, p: *u8, n: i32) { }
fn wait_ms(ctx: *mut u8, ms: i32) { }
fn pulse_rst(ctx: *mut u8) { }

fn main() {
    let wire = lcd.Wire{
        ctx: cast(*mut u8, 0),
        cmd: spi_cmd,
        data: spi_data,
        data_n: spi_data_n,
        delay_ms: wait_ms,
        rst: pulse_rst
    }
    let panel = lcd.attach(wire)
    let mut fb: [15000]u8
    let _ = lcd.clear(fb[:])
    let _ = lcd.rect(fb[:], 20, 40, 380, 80, 0)
    let _ = panel.flush(fb[:])
}
```

## Layout

Directory `klin_st7305/` is one module. `*_test.kl` stays out of `import`.

## License

MIT
