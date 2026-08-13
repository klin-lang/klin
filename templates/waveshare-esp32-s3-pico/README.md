# Waveshare ESP32-S3-Pico blink (`klin init`)

Scaffold from `klin init waveshare-esp32-s3-pico`. Layout:
[054](../../issues/054-embedded-project-layout.md) /
[075](../../issues/075-board-pack-init-host.md). Board pack:
[100](../../issues/100-board-waveshare-esp32-s3-pico.md).

Boot/flash uses **ESP-IDF** (not a freestanding `startup.s` / `linker.ld`).

## Layout

```text
.
  main.kl                 # app (D10 blink)
  main/
    app_main.c            # IDF entry → klin_app_main
    CMakeLists.txt
  CMakeLists.txt
  sdkconfig.defaults      # esp32s3
  Makefile                # emit → idf.py build/flash
  klin.mod                # machine_esp + waveshare_esp32_s3_pico
  README.md
```

Edit `main.kl` — keep the IDF glue unless you know you need to change it.

## How

```sh
. $IDF_PATH/export.sh
klin get                    # once — packages into $KLIN_CACHE
make emit KLIN=/path/to/bin/klin.dart   # or installed `klin`
make build
make flash
```

Needs ESP-IDF **v5.x** on `PATH` (`IDF_PATH`). USB-C on the board is CH343 UART.

Onboard WS2812 (GPIO21): after blink works, switch to `board.rgb_out()` /
`write` (RMT) — see pack [100](../../issues/100-board-waveshare-esp32-s3-pico.md).

## Links

- Issue [100](../../issues/100-board-waveshare-esp32-s3-pico.md), [075](../../issues/075-board-pack-init-host.md), [099](../../issues/099-machine-esp-esp32-s3.md)
- Pack: https://github.com/klin-lang/waveshare_esp32_s3_pico
- Chip: https://github.com/klin-lang/machine_esp
