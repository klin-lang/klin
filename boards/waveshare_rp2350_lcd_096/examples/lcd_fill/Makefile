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

emit: out/lcd_fill.c

out/lcd_fill.c out/lcd_fill.link: lcd_fill.kl $(wildcard $(ROOT)/waveshare_rp2350_lcd_096/*.kl)
	@mkdir -p out
	@case "$(KLIN)" in \
	  *.dart) dart run "$(KLIN)" --emit-c lcd_fill.kl ;; \
	  *) "$(KLIN)" --emit-c lcd_fill.kl ;; \
	esac

elf: lcd_fill.elf

lcd_fill.elf: linker.ld out/lcd_fill.c out/lcd_fill.link
	$(CC) $(CFLAGS) -I. $(LDFLAGS) $$(cat out/lcd_fill.link) out/lcd_fill.c -o $@

clean:
	rm -rf out lcd_fill.elf
