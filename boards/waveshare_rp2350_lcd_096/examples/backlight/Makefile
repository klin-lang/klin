CC := arm-none-eabi-gcc
CFLAGS := -mcpu=cortex-m33 -mthumb -mfloat-abi=soft -ffreestanding -Os -ffunction-sections -fdata-sections
LDFLAGS := -T linker.ld -Wl,--gc-sections -nostdlib

KLIN ?= klin
ROOT := ../..

.PHONY: all emit elf clean deps

all: emit

deps:
	@case "$(KLIN)" in \
	  *.dart) dart run "$(KLIN)" get github/klin-lang/machine_rp@v0.6.0 ;; \
	  *) "$(KLIN)" get github/klin-lang/machine_rp@v0.6.0 ;; \
	esac

emit: out/backlight.c

out/backlight.c out/backlight.link: backlight.kl $(wildcard $(ROOT)/waveshare_rp2350_lcd_096/*.kl)
	@mkdir -p out
	@case "$(KLIN)" in \
	  *.dart) dart run "$(KLIN)" --emit-c backlight.kl ;; \
	  *) "$(KLIN)" --emit-c backlight.kl ;; \
	esac

elf: backlight.elf

backlight.elf: linker.ld out/backlight.c out/backlight.link
	$(CC) $(CFLAGS) -I. $(LDFLAGS) $$(cat out/backlight.link) out/backlight.c -o $@

clean:
	rm -rf out backlight.elf
