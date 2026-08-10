# 095 — Board pack: Waveshare RP2350-LCD-0.96

**Status:** ✅ published `@v0.2.0`  
**Depends on:** [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md), [010](010-bare-metal.md); board pack UX [075](075-board-pack-init-host.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **Small fix:** `emitC` struct typedef topo-order (same as `emitH`) so cross-module struct fields compile |
| Where does the code live? | External: [`klin-lang/waveshare_rp2350_lcd_096`](https://github.com/klin-lang/waveshare_rp2350_lcd_096) `@v0.2.0` |
| Chip API | [`machine_rp`](https://github.com/klin-lang/machine_rp) `@v0.6.0` (`*_rp2350`) |
| Board extras | Pin map + ST7735S + font 5×7 + ADC temp/battery helpers + examples |

## Scope

### `@v0.1.0`

- `pins` / `colors` / `delay` / `lcd_out` (`fill`, `fill_rect`, `hline`/`vline`, `pixel`)
- Examples: `backlight`, `lcd_fill`, `lcd_rects`, `lcd_hello`

### `@v0.2.0`

- Font 5×7: `draw_char` / `draw_text` / `draw_text_n` + `format_u32` / `format_label_u32`
- Text API uses `[]i32` ASCII codes + `draw_text_n` (no `str` indexing in Klin MVP)
- `enable_clk_adc()` + `temp_c_from_adc12` / `battery_mv_from_adc12` / `battery_pct`
- Examples: `lcd_text`, `temp_chip`, `battery_mv`

Tag: [v0.2.0](https://github.com/klin-lang/waveshare_rp2350_lcd_096/releases/tag/v0.2.0)

## Out of scope

- Onboard WS2812 (not in CircuitPython board def for this PCB)
- PIO / DMA LCD, framebuffer heap, LVGL
- `klin init <board>` automation ([075](075-board-pack-init-host.md))

## Published

```sh
klin get github/klin-lang/machine_rp@v0.6.0
klin get github/klin-lang/waveshare_rp2350_lcd_096@v0.2.0
```

## Links

- Repo: https://github.com/klin-lang/waveshare_rp2350_lcd_096  
- Wiki: https://www.waveshare.com/wiki/RP2350-LCD-0.96  
- Chip port: [062](062-targets-esp-rp.md) / [`machine_rp`](https://github.com/klin-lang/machine_rp)  
- Board pack model: [075](075-board-pack-init-host.md)  
