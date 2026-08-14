# 110 — Board pack: Waveshare Pico-LCD-1.14 (Pico form-factor shield)

**Status:** ✅ published `@v0.1.0` (ST7789 fill / rects / backlight)  
**Depends on:** [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md), [075](075-board-pack-init-host.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | External: [`klin-lang/waveshare_pico_lcd_114`](https://github.com/klin-lang/waveshare_pico_lcd_114) `@v0.1.0` |
| Chip API | [`machine_rp`](https://github.com/klin-lang/machine_rp) `@v0.11.0` (SPI / DMA / Pin) |
| Board extras | `lcd_out` / `lcd_out_rp2350` + Pico GP pin map + ST7789 **240×135** helpers + KEY/joystick pin constants |
| Relation to [095](095-board-waveshare-rp2350-lcd-096.md) | **Distinct.** 095 = integrated ST7735S 160×80 on RP2350-LCD-0.96. This pack = **removable Pico-header shield**. |

Track D from [103](103-later-tracks-ble-usb-camera-lcd.md).

## Why a board pack (not `machine_*`)?

Pin maps and ST7789 init/offsets are **board-specific**. `machine_rp` stays generic SPI/DMA/Pin. Same pattern as [095](095-board-waveshare-rp2350-lcd-096.md) / [100](100-board-waveshare-esp32-s3-pico.md).

Pico GP numbers also match Waveshare ESP32-S3-Pico silkscreen; **S3 SPI path** (via `machine_esp`) is a later tag — `@v0.1.0` drives the panel through `machine_rp` only.

## Scope

### `@v0.1.0`

- `pins` — DC/CS/CLK/MOSI/RST/BL + KEY A/B + joystick GP map  
- `lcd_out` (RP2040) / `lcd_out_rp2350` — SPI1 + DMA + ST7789 landscape init (MADCTL `0x70`, offsets 40/53)  
- `fill` / `fill_rect` / `hline` / `vline` / `pixel` / `backlight`  
- Colors (Waveshare-endian RGB565) + `delay_ms`  
- Examples: `backlight`, `lcd_fill`, `lcd_rects`, host `smoke`  
- `version()` → `1`

### Later (not this tag)

- Font / sprites (as on [095](095-board-waveshare-rp2350-lcd-096.md))  
- KEY/joystick read helpers  
- `machine_esp` SPI twin for ESP32-S3-Pico  
- Other Pico LCD sizes (0.96 / 1.3 / 2") as sibling packs  

## Out of scope

- Folding LCD into `machine_rp` / `machine_esp`  
- Replacing [095](095-board-waveshare-rp2350-lcd-096.md)  
- Camera / USB OTG (→ [109](109-esp-camera-idf.md) / [108](108-esp-usb-idf.md))  

## Contract (prime rule)

- No Klin GC / hidden heap — pixels go SPI (+ explicit DMA channel).  
- `peri_clk_hz` / `spi_baud_hz` are caller-supplied.  
- Window offsets are documented Waveshare constants.

## Usage (RP2040 Pico)

```klin
import "github/klin-lang/waveshare_pico_lcd_114" board

@[link("startup.s")]
@[link("boot2_w25q080.S")]
fn main() {
  let lcd = board.lcd_out(125000000, 10000000)
  lcd.backlight(true)
  lcd.fill(board.color_red())
}
```

```sh
klin get github/klin-lang/waveshare_pico_lcd_114@v0.1.0
klin get github/klin-lang/machine_rp@v0.11.0
```

## Links

- Repo: https://github.com/klin-lang/waveshare_pico_lcd_114  
- Tag: [v0.1.0](https://github.com/klin-lang/waveshare_pico_lcd_114/releases/tag/v0.1.0)  
- Wiki: [Pico-LCD-1.14](https://www.waveshare.com/wiki/Pico-LCD-1.14)  
- Parent track: [103](103-later-tracks-ble-usb-camera-lcd.md) (track D MVP)  
- Sibling integrated LCD: [095](095-board-waveshare-rp2350-lcd-096.md)  
- S3-Pico host (pins only, no LCD yet): [100](100-board-waveshare-esp32-s3-pico.md)  
- Chip: [`machine_rp`](https://github.com/klin-lang/machine_rp)  
- Catalog: [061](061-micropython-machine-api.md), targets [062](062-targets-esp-rp.md)  
