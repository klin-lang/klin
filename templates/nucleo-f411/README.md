# Nucleo-F411RE blink (`klin init`)

Scaffold from `klin init nucleo-f411`. Layout: [054](../../issues/054-embedded-project-layout.md)
/ [075](../../issues/075-board-pack-init-host.md). Pinout: [074](../../issues/074-board-ioc-klin-mod.md).

## Layout

```text
.
  main.kl           # app ($device + $board)
  board/
    startup.s       # vectors + Reset_Handler
    linker.ld       # FLASH/RAM map
    nucleo_f411re.ioc  # local pinout truth
  Makefile
  klin.mod          # device SVD pin
  README.md
```

Edit `main.kl` — you should not need to touch `board/` for a blink.
Edit `board/*.ioc` for pin labels; `klin get` will **not** overwrite it.

## How

```sh
klin get                    # once — SVD into $KLIN_CACHE
make KLIN=/path/to/bin/klin.dart   # or installed `klin`
# → main.elf
```

Needs `arm-none-eabi-gcc` on `PATH`.

## Optional board pack

Pin helpers + more examples live outside Klin:

```sh
klin get github/klin-lang/nucleo_f411re@v0.1.2
# require github/klin-lang/nucleo_f411re v0.1.2
```

See [096](../../issues/096-board-nucleo-f411re.md) /
https://github.com/klin-lang/nucleo_f411re

## Links

- Issue [075](../../issues/075-board-pack-init-host.md), [074](../../issues/074-board-ioc-klin-mod.md),
  [096](../../issues/096-board-nucleo-f411re.md), [053](../../issues/053-device-board-assets.md)
- In-repo sibling: [`examples/stm32/device_f411/`](../../examples/stm32/device_f411/)
