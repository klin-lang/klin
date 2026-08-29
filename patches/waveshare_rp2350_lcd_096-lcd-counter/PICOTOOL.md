# Flashing with picotool (RP2350-LCD-0.96)

Klin emits C and links an **ELF**. It does **not** flash the board.
Do **not** rename `*.elf` to `*.uf2` — UF2 is a different format.

## Install picotool

Official tool for Pico / Pico 2 / RP2350:

- Source / releases: https://github.com/raspberrypi/picotool
- macOS: `brew install picotool`
- Linux: distro package if available, otherwise build from the repo above
- Windows: release binaries or build with the Pico SDK toolchain

## Build an example

```sh
cd examples/lcd_counter   # or lcd_fill, lcd_text, …
make deps KLIN=/path/to/klin/bin/klin.dart
make emit KLIN=/path/to/klin/bin/klin.dart
make elf                  # needs arm-none-eabi-gcc
# → lcd_counter.elf
```

## Enter BOOT mode

On this PCB **BOOT** is the ROM UF2 bootloader only. It is wired to
QSPI chip-select — **not** an application GPIO. There is no USER button.

1. Hold **BOOT**
2. Plug USB-C (or hold BOOT and tap **RESET**)
3. Release **BOOT**

The board appears as a USB mass-storage drive (or is ready for `picotool`).

## Load firmware

Preferred (ELF directly):

```sh
picotool load -f lcd_counter.elf
picotool reboot
```

UF2 drag-and-drop: convert ELF → UF2 with `picotool` / `elf2uf2`, then copy
the `.uf2` onto the mass-storage volume.

## Related

- Board wiki: https://www.waveshare.com/wiki/RP2350-LCD-0.96
- Klin scaffold: `klin init waveshare-rp2350-lcd-096`
- Klin issue [095](https://github.com/klin-lang/klin/blob/main/issues/095-board-waveshare-rp2350-lcd-096.md)
