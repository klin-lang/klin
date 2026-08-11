# Nucleo-F411RE blink — remote $device (issue 054 layout).
include ../_common/f411.mk

CC := arm-none-eabi-gcc
CFLAGS := $(CFLAGS_F411)
LDFLAGS := $(LDFLAGS_F411)
KLIN := $(KLIN_ROOT)
KLIN_SRCS := $(KLIN) $(wildcard ../../../lib/*.dart) $(wildcard ../../../lib/svd/*.dart)
REGS_H := stm32f411_regs.h
REGS_KL := stm32f411_regs.kl

.PHONY: all get clean

all: main.elf

get:
	dart run $(KLIN) get

LINK_OBJS := $(shell test -f out/main.link && cat out/main.link)

out/main.c out/main.link $(REGS_H) $(REGS_KL): main.kl klin.mod board/startup.s $(KLIN_SRCS)
	dart run $(KLIN) --emit-c main.kl

main.elf: board/linker.ld out/main.c out/main.link $(REGS_H) $(LINK_OBJS)
	$(CC) $(CFLAGS) -I. $(LDFLAGS) $$(cat out/main.link) out/main.c -o $@

clean:
	rm -rf out main.elf $(REGS_H) $(REGS_KL)
