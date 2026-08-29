# rotary_encoder

Klin driver for a **quadrature rotary encoder** with an optional push switch
(EC11, KY-040, and any A/B + SW mechanical encoder).

Not Arduino, not a HAL, not in the Klin stdlib. The app owns the GPIO pins and
exposes them through `Wire`. This package decodes Gray-code steps and
debounces the button. No heap, no IRQ, no hidden time base.

## Requirements

- [Klin](https://github.com/klin-lang/klin) compiler

## Install

```sh
# After the package is published:
klin get github/klin-lang/rotary_encoder@v0.1.0
```

Until then, use this seed with `-I`:

```sh
klin test patches/rotary_encoder-v0.1.0/rotary_encoder
klin run -I patches/rotary_encoder-v0.1.0 patches/rotary_encoder-v0.1.0/examples/host_smoke.kl
```

## API (`@v0.1.0`)

| Symbol | Meaning |
|---|---|
| `version(): i32` | `1` at `v0.1.0` |
| `ch_a` / `ch_b` / `ch_sw` | Wire channel ids (`0` / `1` / `2`) |
| `default_btn_thresh(): i32` | `3` — debounce in **poll counts**, not ms |
| `ab_code(a, b): i32` | pack A/B into Gray `0..3` |
| `step(prev, curr): i32` | pure decode: `+1` CW, `-1` CCW, `0` idle/illegal |
| `Wire` | `ctx` + `read(ctx, ch) → 0\|1` (no capture) |
| `attach(wire): Dev` | baseline A/B sample; button starts released |
| `attach_debounce(wire, n): Dev` | same, custom button threshold (`n < 1` → `1`) |
| `Event` | `None` / `Cw` / `Ccw` / `Press` / `Release` |
| `Dev.poll(): Event` | one tick; always samples A/B/SW; rotation beats button |

### Wire

`read` returns **logical** levels after the app fixes polarity:

- A / B: `0` or `1`
- SW: `0` = released, `1` = pressed (invert in the app if the pin is active-low)

Unused switch → always return `0`.

```klin
import "github/klin-lang/rotary_encoder" enc

fn pins_read(ctx: *mut u8, ch: i32): i32 {
    // machine_* Pin reads; invert SW if active-low
    return 0
}

fn main() {
    let wire = enc.Wire{ ctx: cast(*mut u8, 0), read: pins_read }
    let mut d = enc.attach(wire)
    match d.poll() {
        enc.Event.Cw { /* volume++ */ }
        enc.Event.Ccw { /* volume-- */ }
        enc.Event.Press { /* select */ }
        else {}
    }
}
```

One detent on a typical EC11 is several Gray steps (often 4). Count `Cw`/`Ccw`
in the app if you want “click” units instead of transitions.

## EC11 example (Elektroweb S-026)

20 PPR module with knob switch. Typical breakout: **CLK/A**, **DT/B**, **SW**
(active-low), **+**, **GND**. Fetch once, then remote import:

```sh
klin get github/klin-lang/rotary_encoder@v0.1.0
```

```klin
module app
import "github/klin-lang/rotary_encoder" enc
// import machine_stm32 m   // or machine_rp / machine_esp

/// Wire your GPIO here, e.g. A=PA0, B=PA1, SW=PA2.
struct Pins {
    // a: m.Pin, b: m.Pin, sw: m.Pin
}

fn ec11_read(ctx: *mut u8, ch: i32): i32 {
    let p = cast(*mut Pins, ctx)
    if ch == enc.ch_a() {
        return 0 // return p.a.value()
    }
    if ch == enc.ch_b() {
        return 0 // return p.b.value()
    }
    // SW active-low → logical pressed = 1
    return 0 // return 1 - p.sw.value()
}

fn main() {
    let mut pins = Pins{}
    let mut d = enc.attach(enc.Wire{
        ctx: cast(*mut u8, &pins),
        read: ec11_read
    })

    let mut volume = 50
    while true {
        match d.poll() {
            enc.Event.Cw {
                if volume < 100 { volume = volume + 1 }
            }
            enc.Event.Ccw {
                if volume > 0 { volume = volume - 1 }
            }
            enc.Event.Press { /* select / mute */ }
            else {}
        }
    }
}
```

Until the upstream repo is tagged, the same sources work via
`-I patches/rotary_encoder-v0.1.0` (local seed mirror).


## Layout

Directory `rotary_encoder/` is one module (`decode.kl` + `encoder.kl` +
`version.kl`). `*_test.kl` stays out of `import`.

## License

MIT
