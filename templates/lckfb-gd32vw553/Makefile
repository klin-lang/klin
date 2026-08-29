# LCKFB GD32VW553 (HMQ-EVT) blink — Klin emit-c + optional RISC-V gcc ELF.
#
#   make get emit KLIN=/path/to/klin/bin/klin.dart
#   make elf  KLIN=…   # needs riscv*-unknown-elf-gcc (rv32imac / ilp32)

# := so a host CC from the environment does not win
CC := riscv64-unknown-elf-gcc
CFLAGS := -march=rv32imac -mabi=ilp32 -ffreestanding -Os -ffunction-sections -fdata-sections
LDFLAGS := -T board/linker.ld -Wl,--gc-sections -nostdlib

KLIN ?= klin

.PHONY: all get emit elf clean

all: emit

get:
	@case "$(KLIN)" in \
	  *.dart) dart run "$(KLIN)" get ;; \
	  *) "$(KLIN)" get ;; \
	esac

emit: out/main.c

out/main.c out/main.link: main.kl klin.mod board/startup.S board/linker.ld
	@mkdir -p out
	@case "$(KLIN)" in \
	  *.dart) dart run "$(KLIN)" --emit-c main.kl ;; \
	  *) "$(KLIN)" --emit-c main.kl ;; \
	esac

elf: main.elf

main.elf: board/linker.ld out/main.c out/main.link
	$(CC) $(CFLAGS) -I. $(LDFLAGS) $$(cat out/main.link) out/main.c -o $@

clean:
	rm -rf out main.elf
