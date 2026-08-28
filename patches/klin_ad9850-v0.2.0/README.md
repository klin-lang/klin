# klin_ad9850

Klin chip driver for the **AD9850** DDS (direct digital synthesis) signal
generator — the common 125 MHz breakout module, driven in **serial** mode.

Not Arduino, not a HAL, not in the Klin stdlib. The app owns the four control
pins (`W_CLK`, `FQ_UD`, `DATA`, `RESET`) and exposes them through `Wire`. This
package builds the 40-bit tuning word and streams it. No heap, no IRQ, no float.

## Requirements

- [Klin](https://github.com/klin-lang/klin) compiler with numeric `cast`
  ([issue 154](https://github.com/klin-lang/klin/blob/main/issues/154-numeric-cast.md))

## Install

```sh
klin get github/klin-lang/klin_ad9850@v0.2.0
```

Repo: https://github.com/klin-lang/klin_ad9850
Local (this mirror or a sibling checkout): `-I` the package root.

```sh
klin test klin_ad9850
klin run -I. examples/host_smoke.kl
```

## API (`@v0.2.0`)

Breaking vs `@v0.1.0`: wire bytes and FTW are typed (`u8` / `u32`) instead of
everything being `i64`. Tuning math still uses an `i64` intermediate via
`cast` (prime rule — the C emission is the hand-written cast).

| Symbol | Meaning |
|---|---|
| `version(): i32` | `2` at `v0.2.0` |
| `default_ref_hz(): u32` | `125000000` — the usual module reference clock |
| `tuning_word(freq_hz, ref_hz): u32` | 32-bit FTW = `floor(freq · 2³² / ref)` |
| `freq_from_word(ftw, ref_hz): u32` | inverse of `tuning_word` (approx Hz) |
| `control_byte(phase, power_down): u8` | W4 byte: `(phase & 31) << 3 \| (pd & 1) << 2` |
| `word_byte(ftw, i): u8` | byte `i` (0 = LSB) of the tuning word |
| `Wire` | `ctx` + `write(u8)` / `latch` / `reset` hooks (no capture) |
| `attach(wire, ref_hz): Dev` | store wire + reference clock; no heap |
| `Dev.send(ftw, phase, power_down)` | stream the 40-bit word, then latch |
| `Dev.set_freq(freq_hz)` | program a frequency (phase 0, powered up) |
| `Dev.set_freq_phase(freq_hz, phase)` | frequency + 5-bit phase (`0..31`) |
| `Dev.power_down()` | latch the power-down bit |
| `Dev.reset()` | pulse `RESET` through the wire |

Phase is a 5-bit code — 11.25° per step.

### Wire

- `write(ctx, byte)` — clock out one byte **LSB first** (`D0` first), pulsing
  `W_CLK` on each bit.
- `latch(ctx)` — pulse `FQ_UD` to load the 40 shifted bits into the DDS core.
- `reset(ctx)` — pulse `RESET`, then re-enter serial mode. Most modules hardwire
  the mode pins for serial; after `RESET` a single `W_CLK` then `FQ_UD` pulse
  selects serial load (board-specific, so it lives in the app).

```klin
import klin_ad9850 dds

// One byte, LSB first, over app-owned GPIO (pseudo — supply your machine_* pins).
fn dds_write(ctx: *mut u8, b: u8) {
    let mut bit: u8 = 0
    while bit < 8 {
        // data.set((b >> bit) & 1); wclk.high(); wclk.low()
        bit = bit + 1
    }
}
fn dds_latch(ctx: *mut u8) { /* fq_ud.high(); fq_ud.low() */ }
fn dds_reset(ctx: *mut u8) { /* rst.high(); rst.low(); prime serial mode */ }

fn main() {
    let wire = dds.Wire{
        ctx: cast(*mut u8, 0),
        write: dds_write,
        latch: dds_latch,
        reset: dds_reset
    }
    let d = dds.attach(wire, dds.default_ref_hz())
    d.reset()
    d.set_freq(1000000)          // 1 MHz sine/square out
    d.set_freq_phase(1000000, 8) // same tone, +90°
}
```

## Layout

Directory `klin_ad9850/` is one module (`word.kl` + `dds.kl` + `version.kl`).
`*_test.kl` stays out of `import`. Host smoke test: `examples/host_smoke.kl`.

## License

MIT
