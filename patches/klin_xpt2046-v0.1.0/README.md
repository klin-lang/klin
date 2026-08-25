# klin_xpt2046

Klin chip driver for the **XPT2046** resistive touch controller (SPI).

Not Adafruit `TouchScreen`, not Arduino, not in the Klin stdlib. The app
owns the bus (`machine_*` `Spi` + `Pin`, or any other C/Klin hooks). This
package sends 8-bit commands and reads 12-bit ADC samples.

Typical panel: cheap 1.8″ ST7735S modules with a touch overlay (e.g.
[msalamon TFT-00008](https://sklep.msalamon.pl/produkt/wyswietlacz-dotykowy-tft-lcd-1-8″-128x160px-rgb-spi-st7735s/)).
LCD stays in [`klin_st7735`](https://github.com/klin-lang/klin_st7735). SD /
FatFs is a [later package](https://github.com/klin-lang/klin/blob/main/issues/150-sd-spi-fatfs.md).

## Requirements

- [Klin](https://github.com/klin-lang/klin) compiler

## Install

When published:

```sh
klin get github/klin-lang/klin_xpt2046@v0.1.0
```

Until the external repo exists, use this seed from the Klin tree:

```sh
klin test -I patches/klin_xpt2046-v0.1.0 klin_xpt2046
klin run -I patches/klin_xpt2046-v0.1.0 patches/klin_xpt2046-v0.1.0/examples/host_smoke.kl
```

## API (`@v0.1.0`)

| Symbol | Meaning |
|---|---|
| `version(): i32` | `1` at `v0.1.0` |
| `Wire` | `xfer(ctx, cmd) → i32` + `ctx` (no capture) |
| `attach(wire)` | store wire; no heap |
| `raw()` | one X/Y/Z sample (12-bit); always reads |
| `pressed(z_thresh)` | `1` if `z >= z_thresh` else `0` |
| `read(z_thresh)` | raw sample; clears X/Y to `0` when not pressed |
| `adc12(raw16)` | `(raw16 >> 3) & 0xFFF` |
| `map(v, in0, in1, out0, out1)` | linear map (app calibration) |
| `default_z_thresh()` | `400` |
| `cmd_x` / `cmd_y` / `cmd_z1` / `cmd_z2` | control bytes (12-bit, differential) |

No heap, no IRQ magic, no calibration tables inside the driver. SPI:
**Mode 0**, MSB first; baud is caller-owned (often ≤ 2 MHz).

### Wire

`xfer` must: CS low → write 8-bit `cmd` → clock 16 MISO bits (return as
`i32`) → CS high. Other SPI devices on the same bus keep their CS HIGH.

```klin
import klin_xpt2046 touch

fn spi_xfer(ctx: *mut u8, cmd: i32): i32 {
    // CS low, write cmd, read 16 bits, CS high
    return 0
}

fn main() {
    let wire = touch.Wire{ ctx: cast(*mut u8, 0), xfer: spi_xfer }
    let t = touch.attach(wire)
    let s = t.read(touch.default_z_thresh())
    if s.z >= touch.default_z_thresh() {
        printf("x=%d y=%d\n", s.x, s.y)
    }
}
```

## Layout

Directory `klin_xpt2046/` is one module. `*_test.kl` stays out of `import`.

## License

MIT
