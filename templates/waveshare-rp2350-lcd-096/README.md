# Waveshare RP2350-LCD-0.96 backlight (`klin init`)

Scaffold from `klin init waveshare-rp2350-lcd-096`. Layout:
[054](../../issues/054-embedded-project-layout.md) /
[075](../../issues/075-board-pack-init-host.md). Board pack:
[095](../../issues/095-board-waveshare-rp2350-lcd-096.md).

## Layout

```text
.
  main.kl              # app (backlight blink)
  board/
    startup.s          # vectors + Reset_Handler
    linker.ld          # FLASH/RAM map
    image_def.S        # RP2350 PICOBIN IMAGE_DEF
  Makefile
  klin.mod             # machine_rp + waveshare_rp2350_lcd_096
  README.md
```

Edit `main.kl` — you should not need to touch `board/` for a blink.

## How

```sh
klin get                    # once — packages into $KLIN_CACHE
make KLIN=/path/to/bin/klin.dart   # or installed `klin`
# → main.elf
```

Needs `arm-none-eabi-gcc` on `PATH`.

### Flash

Klin does not flash the chip. Full UF2 / `picotool` steps (BOOT is
bootloader-only, not an app GPIO):

- Pack PR: https://github.com/klin-lang/waveshare_rp2350_lcd_096/pull/14
  (`PICOTOOL.md`, `examples/lcd_counter`)
- Mirror seed in Klin:
  [`patches/waveshare_rp2350_lcd_096-lcd-counter/`](../../patches/waveshare_rp2350_lcd_096-lcd-counter/)

Short version: hold **BOOT**, plug USB-C, then
`picotool load -f main.elf && picotool reboot`. Do not rename `.elf` → `.uf2`.

## Links

- Issue [095](../../issues/095-board-waveshare-rp2350-lcd-096.md), [075](../../issues/075-board-pack-init-host.md)
- Pack: https://github.com/klin-lang/waveshare_rp2350_lcd_096
- Embedded walkthrough: [docs/embedded.md](../../docs/embedded.md)
