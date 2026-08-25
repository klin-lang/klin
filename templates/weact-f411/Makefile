# := so a host CC from the environment does not win
CC := arm-none-eabi-gcc
OBJCOPY := arm-none-eabi-objcopy
CFLAGS := -mcpu=cortex-m4 -mthumb -ffreestanding -Os -ffunction-sections -fdata-sections
LDFLAGS := -T board/linker.ld -Wl,--gc-sections -nostdlib

# Override: make KLIN=/path/to/klin/bin/klin.dart
KLIN ?= klin

.PHONY: all get emit elf bin flash flash-swd clean

all: elf

get:
	@case "$(KLIN)" in \
	  *.dart) dart run "$(KLIN)" get ;; \
	  *) "$(KLIN)" get ;; \
	esac

emit: out/main.c

out/main.c out/main.link: main.kl klin.mod board/startup.s board/linker.ld
	@mkdir -p out
	@case "$(KLIN)" in \
	  *.dart) dart run "$(KLIN)" --emit-c main.kl ;; \
	  *) "$(KLIN)" --emit-c main.kl ;; \
	esac

elf: main.elf

main.elf: board/linker.ld out/main.c out/main.link
	$(CC) $(CFLAGS) -I. $(LDFLAGS) $$(cat out/main.link) out/main.c -o $@

bin: main.bin

main.bin: main.elf
	$(OBJCOPY) -O binary $< $@

# ROM DFU — same tool STM32duino uses. Hold BOOT0, tap NRST (or plug USB-C).
# Klin does not flash; this target only runs dfu-util.
flash: main.bin
	dfu-util -a 0 -s 0x08000000:leave -D main.bin

# External ST-Link / J-Link on SWDIO / SWCLK / GND / 3V3.
flash-swd: main.bin
	st-flash write main.bin 0x08000000

clean:
	rm -rf out main.elf main.bin
