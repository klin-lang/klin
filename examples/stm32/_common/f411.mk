# Shared Nucleo-F411RE freestanding flags (issue 054).
# Include from a demo Makefile: `include ../_common/f411.mk`

CC := arm-none-eabi-gcc
CFLAGS_F411 := -mcpu=cortex-m4 -mthumb -ffreestanding -Os \
	-ffunction-sections -fdata-sections
LDFLAGS_F411 := -T board/linker.ld -Wl,--gc-sections -nostdlib

# Path to Klin entry relative to examples/stm32/<demo>/
KLIN_ROOT ?= ../../../bin/klin.dart
