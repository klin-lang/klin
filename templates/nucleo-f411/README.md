# Nucleo-F411RE blink (`klin init`)

Scaffold from `klin init nucleo-f411`. Layout: [054](../../issues/054-embedded-project-layout.md)
/ [075](../../issues/075-board-pack-init-host.md).

## Layout

```text
.
  main.kl           # app
  board/
    startup.s       # vectors + Reset_Handler
    linker.ld       # FLASH/RAM map
  Makefile
  klin.mod          # device SVD pin
  README.md
```

Edit `main.kl` — you should not need to touch `board/` for a blink.

## How

```sh
klin get                    # once — SVD into $KLIN_CACHE
make KLIN=/path/to/bin/klin.dart   # or installed `klin`
# → main.elf
```

Needs `arm-none-eabi-gcc` on `PATH`.

## Links

- Issue [075](../../issues/075-board-pack-init-host.md), [053](../../issues/053-device-board-assets.md)
- In-repo sibling: [`examples/stm32/device_f411/`](../../examples/stm32/device_f411/)
