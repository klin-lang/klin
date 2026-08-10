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

emit: out/lcd_hello.c

out/lcd_hello.c out/lcd_hello.link: lcd_hello.kl $(wildcard $(ROOT)/waveshare_rp2350_lcd_096/*.kl)
	@mkdir -p out
	@case "$(KLIN)" in \
	  *.dart) dart run "$(KLIN)" --emit-c lcd_hello.kl ;; \
	  *) "$(KLIN)" --emit-c lcd_hello.kl ;; \
	esac

elf: lcd_hello.elf

lcd_hello.elf: linker.ld out/lcd_hello.c out/lcd_hello.link
	$(CC) $(CFLAGS) -I. $(LDFLAGS) $$(cat out/lcd_hello.link) out/lcd_hello.c -o $@

clean:
	rm -rf out lcd_hello.elf
