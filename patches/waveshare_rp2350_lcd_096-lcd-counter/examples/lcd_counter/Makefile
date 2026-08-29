CC := arm-none-eabi-gcc
CFLAGS := -mcpu=cortex-m33 -mthumb -mfloat-abi=soft -ffreestanding -Os -ffunction-sections -fdata-sections
LDFLAGS := -T linker.ld -Wl,--gc-sections --specs=nano.specs -nostartfiles

KLIN ?= klin
ROOT := ../..

.PHONY: all emit elf clean deps

all: emit

deps:
	@case "$(KLIN)" in \
	  *.dart) dart run "$(KLIN)" get github/klin-lang/machine_rp@v0.11.0 ;; \
	  *) "$(KLIN)" get github/klin-lang/machine_rp@v0.11.0 ;; \
	esac

emit: out/lcd_counter.c

out/lcd_counter.c out/lcd_counter.link: lcd_counter.kl $(wildcard $(ROOT)/waveshare_rp2350_lcd_096/*.kl)
	@mkdir -p out
	@case "$(KLIN)" in \
	  *.dart) dart run "$(KLIN)" --emit-c lcd_counter.kl ;; \
	  *) "$(KLIN)" --emit-c lcd_counter.kl ;; \
	esac

elf: lcd_counter.elf

lcd_counter.elf: linker.ld out/lcd_counter.c out/lcd_counter.link
	$(CC) $(CFLAGS) -I. $(LDFLAGS) $$(cat out/lcd_counter.link) out/lcd_counter.c -o $@

clean:
	rm -rf out lcd_counter.elf
