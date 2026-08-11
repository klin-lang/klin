# := so a host CC from the environment does not win
CC := arm-none-eabi-gcc
CFLAGS := -mcpu=cortex-m4 -mthumb -ffreestanding -Os -ffunction-sections -fdata-sections
LDFLAGS := -T board/linker.ld -Wl,--gc-sections -nostdlib

# Override: make KLIN=/path/to/klin/bin/klin.dart
KLIN ?= klin

.PHONY: all get emit elf clean

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

clean:
	rm -rf out main.elf stm32f411_regs.h stm32f411_regs.kl
