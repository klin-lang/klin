# Patches for external Klin packages

Apply against the named upstream repo when the cloud agent cannot push
there. New-package **seeds** may live here until published; keep the tree
as a mirror after the first tag if useful for offline `-I`.

| Patch / seed | Upstream | Klin issue |
|---|---|---|
| [machine_avr-v0.3.0-atmega32u4.patch](machine_avr-v0.3.0-atmega32u4.patch) | [`klin-lang/machine_avr`](https://github.com/klin-lang/machine_avr) **merged** → [`v0.3.0`](https://github.com/klin-lang/machine_avr/releases/tag/v0.3.0) | [142](../issues/142-machine-avr-atmega32u4.md) ✅ |
| [klin_xpt2046-v0.1.0/](klin_xpt2046-v0.1.0/) | [`klin-lang/klin_xpt2046`](https://github.com/klin-lang/klin_xpt2046) **published** → [`v0.1.0`](https://github.com/klin-lang/klin_xpt2046/releases/tag/v0.1.0) | [149](../issues/149-klin-xpt2046.md) ✅ |
| [klin_ad9850-v0.1.0/](klin_ad9850-v0.1.0/) | [`klin-lang/klin_ad9850`](https://github.com/klin-lang/klin_ad9850) **published** → [`v0.1.0`](https://github.com/klin-lang/klin_ad9850/releases/tag/v0.1.0) | [153](../issues/153-klin-ad9850.md) ✅ |
| [klin_ad9850-v0.2.0/](klin_ad9850-v0.2.0/) | [`klin-lang/klin_ad9850`](https://github.com/klin-lang/klin_ad9850) **published** → [`v0.2.0`](https://github.com/klin-lang/klin_ad9850/releases/tag/v0.2.0) (typed `u8`/`u32` + numeric `cast`) | [153](../issues/153-klin-ad9850.md) ✅ |
| [rotary_encoder-v0.1.0/](rotary_encoder-v0.1.0/) | [`klin-lang/rotary_encoder`](https://github.com/klin-lang/rotary_encoder) seed — quadrature A/B + switch `Wire`; tag when published | [155](../issues/155-rotary-encoder.md) 🔨 |
| [waveshare_rp2350_lcd_096-lcd-counter/](waveshare_rp2350_lcd_096-lcd-counter/) + [`.patch`](waveshare_rp2350_lcd_096-lcd-counter.patch) | [`klin-lang/waveshare_rp2350_lcd_096`](https://github.com/klin-lang/waveshare_rp2350_lcd_096) — `PICOTOOL.md` + `examples/lcd_counter` (agent push 403) | [095](../issues/095-board-waveshare-rp2350-lcd-096.md) 🔨 |

```sh
cd /path/to/machine_avr
git checkout main && git pull
git apply /path/to/klin/patches/machine_avr-v0.3.0-atmega32u4.patch
```

```sh
klin get github/klin-lang/klin_xpt2046@v0.1.0
klin test klin_xpt2046
```
