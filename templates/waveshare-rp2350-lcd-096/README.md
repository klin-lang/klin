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

Needs `arm-none-eabi-gcc` on `PATH`. Flash with your usual UF2 / picotool flow.

## Links

- Issue [095](../../issues/095-board-waveshare-rp2350-lcd-096.md), [075](../../issues/075-board-pack-init-host.md)
- Pack: https://github.com/klin-lang/waveshare_rp2350_lcd_096
