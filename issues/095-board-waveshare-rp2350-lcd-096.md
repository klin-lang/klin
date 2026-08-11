# 095 — Board pack: Waveshare RP2350-LCD-0.96

**Status:** ✅ published `@v0.7.0`  
**Depends on:** [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md), [010](010-bare-metal.md); board pack UX [075](075-board-pack-init-host.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **Small fix:** `emitC` struct typedef topo-order (same as `emitH`) so cross-module struct fields compile |
| Where does the code live? | External: [`klin-lang/waveshare_rp2350_lcd_096`](https://github.com/klin-lang/waveshare_rp2350_lcd_096) `@v0.7.0` |
| Chip API | [`machine_rp`](https://github.com/klin-lang/machine_rp) `@v0.7.0` (`*_rp2350`; includes **Pio**) |
| Board extras | Pin map + ST7735S + font + ADC + UART0 + sprites + light-sleep + WS2812 + Hazard3 RISC-V twin + examples |

## Scope

### `@v0.1.0`

- `pins` / `colors` / `delay` / `lcd_out` (`fill`, `fill_rect`, `hline`/`vline`, `pixel`)
- Examples: `backlight`, `lcd_fill`, `lcd_rects`, `lcd_hello`

### `@v0.2.0`

- Font 5×7: `draw_char` / `draw_text` / `draw_text_n` + `format_u32` / `format_label_u32`
- Text API uses `[]i32` ASCII codes + `draw_text_n` (no `str` indexing in Klin MVP)
- `enable_clk_adc()` + `temp_c_from_adc12` / `battery_mv_from_adc12` / `battery_pct`
- Examples: `lcd_text`, `temp_chip`, `battery_mv`

### `@v0.3.0`

- UART0 pin helpers (GP0/GP1) + `uart0_out` / `uart_write_codes` / `uart_write_codes_n`
- Example: `uart_console` (LCD TX/RX/CH counters + serial banner/echo @ 115200)
- Note: Type-C is native USB — console needs external USB–UART on the header

### `@v0.4.0`

- `blit_mono8` / `blit_mono8_trans` (8 row bytes, bit7 = leftmost)
- Stock icons: heart / check / cross / battery / arrow_r / smile
- Example: `lcd_sprites`

### `@v0.5.0`

- Light sleep: `sleep_cpu_hz` / `sleep_systick_reload` (host-safe math)
- Example: `sleep_demo` — SysTick + WFI, backlight off, wake counter (`N=`)
- Not POWMAN deep sleep / dormant; no USER button on this PCB (timer wake)

### `@v0.6.0`

- External WS2812 bit-bang on GP15 (`ws2812_data` / `ws2812_out` / `show`)
- Buffer `0x00RRGGBB` → GRB on the wire; tunable `ws2812_t*` loops (no PIO)
- Example: `ws2812_strip` — 8-LED chase + LCD status

### `@v0.7.0`

- Hazard3 RISC-V twin: `examples/riscv_lcd_text` (same Klin LCD, RV32 crt0 + IMAGE_DEF `0x1101`)
- Toolchain: `riscv64-unknown-elf-gcc -march=rv32imac -mabi=ilp32` + `mem.S` stubs
- Arm demos unchanged; `sleep_demo` stays Arm-only (SysTick)

Tag: [v0.7.0](https://github.com/klin-lang/waveshare_rp2350_lcd_096/releases/tag/v0.7.0)

## Out of scope

- Onboard WS2812 (none on this PCB)
- PIO WS2812 / PIO·DMA LCD (chip PIO is in `machine_rp@v0.7.0`; board helpers later)
- USB CDC ACM console (native USB stack)
- POWMAN deep sleep / XOSC dormant resume
- `klin init <board>` automation ([075](075-board-pack-init-host.md))

## Published

```sh
klin get github/klin-lang/machine_rp@v0.7.0
klin get github/klin-lang/waveshare_rp2350_lcd_096@v0.7.0
```

## Links

- Repo: https://github.com/klin-lang/waveshare_rp2350_lcd_096  
- Wiki: https://www.waveshare.com/wiki/RP2350-LCD-0.96  
- Chip port: [062](062-targets-esp-rp.md) / [`machine_rp`](https://github.com/klin-lang/machine_rp)  
- Board pack model: [075](075-board-pack-init-host.md)  
