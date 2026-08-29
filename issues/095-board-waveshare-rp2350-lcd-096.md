# 095 — Board pack: Waveshare RP2350-LCD-0.96

**Status:** ✅ published `@v0.13.0`  
**Depends on:** [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md), [010](010-bare-metal.md); board pack UX [075](075-board-pack-init-host.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **Small fix:** `emitC` struct typedef topo-order (same as `emitH`) so cross-module struct fields compile; package install copies `@[link]` `.c`/`.h`/`.s`; `--emit-c` `.link` resolves absolute paths |
| Where does the code live? | External: [`klin-lang/waveshare_rp2350_lcd_096`](https://github.com/klin-lang/waveshare_rp2350_lcd_096) `@v0.13.0` |
| Chip API | [`machine_rp`](https://github.com/klin-lang/machine_rp) `@v0.11.0` (`*_rp2350`; **Pio** + **Dma** + **UsbCdc**) |
| Board extras | Pin map + ST7735S (**DMA→SPI1** or **PIO-as-SPI**) + font + ADC + UART0 + **USB CDC** + sprites + light-sleep + **oscillator dormant** + **POWMAN** + WS2812 (PIO) + Hazard3 RISC-V twin + examples |

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
- Note (pre-`@v0.11.0`): Type-C is native USB — UART console needs external USB–UART on the header; CDC ACM lands in `@v0.11.0`

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

### `@v0.8.0`

- External WS2812 on GP15 via **PIO0 SM0** (`machine_rp@v0.8.0` side-set program)
- Same `ws2812_out` / `show` API; bit-bang kept as `ws2812_bb_*`
- Example `ws2812_strip` unchanged at the call site

### `@v0.9.0`

- **POWMAN** switched-core power-down with LPOSC 1 kHz timer alarm wake
- Helpers: `powman_timer_start_lposc` / `powman_alarm_in_ms` / `powman_enter_swcore_off` + scratch / `powman_woke_from_swcore_pd`
- Wake **reboots** the cores — wake count in `powman_scratch_*`
- Example: `powman_demo` (Arm); `sleep_demo` light-sleep unchanged

### `@v0.10.0`

- **DMA→SPI1** bulk LCD pixels (`machine_rp@v0.9.0`)
- `fill` / `fill_rect`: `write_dma_repeat2` (2-byte RGB565 read-ring); `blit_mono8`: 128 B + `write_dma`
- Channel: `lcd_dma_ch()` → 0; DC/CS stay CPU GPIO; commands / `pixel` stay byte SPI
- Closes board “PIO·DMA LCD” checklist as DMA-paced HW SPI (PIO-as-SPI remux → `@v0.12.0`)

### `@v0.11.0`

- **USB CDC ACM** Type-C console (`machine_rp@v0.10.0` freestanding poll driver)
- Clocks: `usb_clock.kl` — XOSC → PLL_USB 48 MHz → `clk_usb` (caller-owned; no hidden clock)
- IO: `usb_cdc_out` / `usb_write_codes*` (`poll` + `write_u8`); example `usb_console` (LCD banner + echo)
- UART console (`uart_console`) unchanged — header USB–UART still valid

### `@v0.12.0`

- **PIO-as-SPI LCD** remux (`machine_rp@v0.11.0`: `out_pins` + PIO TX DREQ + `wait_tx_stall`)
- `lcd_pio_out(sys_hz, bit_hz)` / `LcdPio` — GP10/11 → PIO0 SM1 @ instr offset 4 (WS2812 keeps SM0 @0..=3)
- Bulk: DMA→PIO TXF + stall before CS; DC/CS/RST stay GPIO; HW `lcd_out` unchanged
- Example: `lcd_pio_fill` (solid color cycle)

### `@v0.13.0`

- **Oscillator dormant** without POWMAN SWCORE PD (RAM/PC survive; no reboot)
- Timer path (stock PCB, no USER button): `dormant_clocks_prep_lposc_timer` → `powman_alarm_in_ms` → `rosc_enter_dormant` → `powman_alarm_disarm` → `dormant_clocks_restore_rosc`
- GPIO path (header): `dormant_clocks_prep_xosc` + `dormant_wake_gpio_enable` + `xosc_enter_dormant`
- Example: `xosc_dormant_demo` — stock **timer/ROSC** path above (name keeps roadmap “XOSC dormant”); LCD `DORM 0.13` / `AWAKE` + `N=`
- Tier contrast: `sleep_demo` (clocks keep running) / dormant (oscillator stop) / `powman_demo` (SWCORE PD reboot)

Tag: [v0.13.0](https://github.com/klin-lang/waveshare_rp2350_lcd_096/releases/tag/v0.13.0)

## Out of scope

- Onboard WS2812 (none on this PCB)
- USB IRQ / TinyUSB stack (polling ACM only)

## Scaffold

```sh
klin init waveshare-rp2350-lcd-096 my_board
cd my_board && klin get && make
```

Bundled in Klin `templates/waveshare-rp2350-lcd-096/` ([075](075-board-pack-init-host.md)).

## Published

```sh
klin get github/klin-lang/machine_rp@v0.11.0
klin get github/klin-lang/waveshare_rp2350_lcd_096@v0.13.0
```

## Links

- Repo: https://github.com/klin-lang/waveshare_rp2350_lcd_096  
- Flash + `lcd_counter`: [pack PR #14](https://github.com/klin-lang/waveshare_rp2350_lcd_096/pull/14)
  (`PICOTOOL.md`, `examples/lcd_counter`); Klin mirror
  [`patches/waveshare_rp2350_lcd_096-lcd-counter/`](../patches/waveshare_rp2350_lcd_096-lcd-counter/)  
- Wiki: https://www.waveshare.com/wiki/RP2350-LCD-0.96  
- Chip port: [062](062-targets-esp-rp.md) / [`machine_rp`](https://github.com/klin-lang/machine_rp)  
- Board pack model: [075](075-board-pack-init-host.md)  
