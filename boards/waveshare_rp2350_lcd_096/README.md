# waveshare_rp2350_lcd_096

Board pack for [Waveshare RP2350-LCD-0.96](https://www.waveshare.com/wiki/RP2350-LCD-0.96)
in [Klin](https://github.com/klin-lang/klin).

**Canonical repo:** https://github.com/klin-lang/waveshare_rp2350_lcd_096  
This tree under `klin` is a working mirror for the compiler PR / emitC fix.

Not a MicroPython port. No GC, no hidden heap, no hidden clocks.

Chip API: [`machine_rp`](https://github.com/klin-lang/machine_rp) (`*_rp2350`).
This package adds **pin map + ST7735S LCD** for this board only.

## Status (`@v0.1.0`)

| Piece | Status |
|---|---|
| Pin map (LCD / VBUS / battery ADC) | ✅ |
| ST7735S 160×80 (`lcd_out`, `fill`, `fill_rect`, lines) | ✅ |
| Backlight GPIO | ✅ |
| Examples (`backlight`, `lcd_fill`, `lcd_rects`, `lcd_hello`) | ✅ |
| Onboard WS2812 | — not in CircuitPython board def; use external strip later |
| PIO / DMA LCD | later |
| Font / framebuffer alloc | later (explicit buffers only) |

`version()` → `1`.

## Pins (LCD)

| Signal | GPIO |
|---|---|
| DC | 8 |
| CS | 9 |
| SCLK | 10 |
| MOSI | 11 |
| RST | 12 |
| BL | 25 |
| SPI | SPI1 |

Offsets: X+1, Y+26 (Waveshare 160×80). MADCTL `0xA8`.

## Usage

```klin
import "github/klin-lang/waveshare_rp2350_lcd_096" board

fn main() {
    let lcd = board.lcd_out(12000000, 1000000)
    lcd.backlight(true)
    lcd.fill(board.color_red())
}
```

```sh
klin get github/klin-lang/machine_rp@v0.6.0
klin get github/klin-lang/waveshare_rp2350_lcd_096@v0.1.0
```

## Examples (Arm Cortex-M33)

```sh
cd examples/backlight   # or lcd_fill / lcd_rects / lcd_hello
make deps KLIN=/path/to/klin/bin/klin.dart
make emit KLIN=/path/to/klin/bin/klin.dart
make elf                # needs arm-none-eabi-gcc
```

Flash the `.elf` / UF2 with your usual Pico 2 / RP2350 flow (picotool, OpenOCD, …).

## License

MIT
