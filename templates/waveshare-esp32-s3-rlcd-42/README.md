# Waveshare ESP32-S3-RLCD-4.2 (`klin init`)

Scaffold from `klin init waveshare-esp32-s3-rlcd-42`. Layout:
[054](../../issues/054-embedded-project-layout.md) /
[075](../../issues/075-board-pack-init-host.md). Board pack:
[163](../../issues/163-board-waveshare-esp32-s3-rlcd-42.md).

Boot/flash uses **ESP-IDF** (not a freestanding `startup.s` / `linker.ld`).
Demo: clear the ST7305 RLCD, draw a black bar + text, flush.

## Layout

```text
.
  main.kl                 # app (panel clear / bar / text / flush)
  main/
    app_main.c            # IDF entry → klin_app_main
    CMakeLists.txt
  CMakeLists.txt
  sdkconfig.defaults      # esp32s3 + octal PSRAM 80MHz
  Makefile                # emit → idf.py build/flash
  klin.mod                # machine_esp + klin_st7305 + waveshare_esp32_s3_rlcd_42
  README.md
```

## How

```sh
. $IDF_PATH/export.sh
klin get                    # once — packages into $KLIN_CACHE
make emit KLIN=/path/to/bin/klin.dart   # or installed `klin`
make build
make flash
```

Needs ESP-IDF **v5.x** (`IDF_PATH`). USB-C is for flash / log / charging.

**18650:** after inserting the cell, connect USB-C once to activate the
battery protection circuit (Waveshare FAQ). Then you can run on battery.

## Links

- Issue [163](../../issues/163-board-waveshare-esp32-s3-rlcd-42.md), [164](../../issues/164-klin-st7305.md), [075](../../issues/075-board-pack-init-host.md), [099](../../issues/099-machine-esp-esp32-s3.md)
- Pack: https://github.com/klin-lang/waveshare_esp32_s3_rlcd_42
- Panel driver: https://github.com/klin-lang/klin_st7305
- Chip: https://github.com/klin-lang/machine_esp
- Waveshare product: https://www.waveshare.com/esp32-s3-rlcd-4.2.htm
- Waveshare docs: https://docs.waveshare.com/ESP32-S3-RLCD-4.2
- Waveshare demos: https://github.com/waveshareteam/ESP32-S3-RLCD-4.2
- Sibling S3 Pico: [100](../../issues/100-board-waveshare-esp32-s3-pico.md)
