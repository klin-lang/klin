# 155 — `rotary_encoder` quadrature + switch driver

**Status:** 🔨 seed [`patches/rotary_encoder-v0.1.0/`](../patches/rotary_encoder-v0.1.0/)
(awaiting upstream [`klin-lang/rotary_encoder`](https://github.com/klin-lang/rotary_encoder) `@v0.1.0`)  
**Depends on:** [020](020-klin-libraries.md), [049](049-remote-imports.md), [072](072-enums.md);
sibling pattern [149](149-klin-xpt2046.md) / [153](153-klin-ad9850.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | External: `klin-lang/rotary_encoder`; seed under `patches/` until published |
| MCU pins in the driver? | **No** — the app owns A / B / SW via `Wire` |
| Product-specific EC11 SKU lib? | **No** — generic quadrature; EC11 / KY-040 / similar all fit |
| Board pack? | **No** — pinout is app wiring |

## Why separate

A mechanical rotary encoder is three digital lines and a Gray-code table. Folding
that into `machine_*` or a shop-SKU package would couple GPIO HALs and product
pages to every app that only needs “turn / click”. Same MCU-agnostic `Wire` /
`ctx` pattern as [`klin_xpt2046`](https://github.com/klin-lang/klin_xpt2046) and
[`klin_ad9850`](https://github.com/klin-lang/klin_ad9850).

## Scope (`@v0.1.0`)

- `Wire.read(ctx, ch)` — logical `0`/`1` for `ch_a` / `ch_b` / `ch_sw`
- `step(prev, curr)` — pure Gray decode (`+1` / `-1` / `0`)
- `attach` / `attach_debounce` — no heap; baseline A/B sample
- `Dev.poll(): Event` — always samples A/B/SW; rotation beats button on the same tick
- Button debounce in **poll counts** (caller owns the time base)
- Host `klin test` + `examples/host_smoke.kl`

### Later (not this tag)

- ISR / edge helpers (app can poll a `Pin` or call `poll` from a timer today)
- Full-cycle / detent accumulators (app can count `Cw`/`Ccw`)
- Absolute / I²C / SPI encoders (different package)

## Out of scope

- Board packs, HAL, or a specific `machine_*` dependency
- Hidden allocation, IRQ magic, or ms-based timing inside the driver
- Shop-SKU wrappers (Elektroweb EC11, KY-040 breakout names, …)

## Contract (prime rule)

- No Klin GC / hidden heap; the emitted C is the table lookup you would write by hand.
- Illegal Gray jumps (both bits flip) produce `0` — no invented steps.
- Debounce threshold is poll counts, not milliseconds.

## Usage

```sh
klin get github/klin-lang/rotary_encoder@v0.1.0
```

```klin
import "github/klin-lang/rotary_encoder" enc
```

Until publish, the seed still runs locally:

```sh
klin test patches/rotary_encoder-v0.1.0/rotary_encoder
klin run -I patches/rotary_encoder-v0.1.0 \
  patches/rotary_encoder-v0.1.0/examples/host_smoke.kl
```

## Links

- Seed: [`patches/rotary_encoder-v0.1.0/`](../patches/rotary_encoder-v0.1.0/)
- Planned repo: https://github.com/klin-lang/rotary_encoder
- Sibling drivers: [149](149-klin-xpt2046.md), [153](153-klin-ad9850.md)
