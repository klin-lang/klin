# Nucleo-F411RE blink — local SVD (issue 054 layout).
include ../_common/f411.mk

CC := arm-none-eabi-gcc
CFLAGS := $(CFLAGS_F411)
LDFLAGS := $(LDFLAGS_F411)
KLIN := $(KLIN_ROOT)
KLIN_SRCS := $(KLIN) $(wildcard ../../../lib/*.dart)
REGS_H := stm32f411_regs.h
REGS_KL := stm32f411_regs.kl
SVD := ../../../third_party/svd/stm32f411.svd

.PHONY: all ref clean

all: main.elf

$(REGS_H) $(REGS_KL): $(SVD) $(wildcard ../../../lib/svd/*.dart) ../../../bin/svd2klin.dart
	dart run ../../../bin/svd2klin.dart --svd $(SVD) --out-h $(REGS_H) --out-kl $(REGS_KL) --peripherals RCC,GPIOA,STK

# @[link] paths land in out/main.link (issue 022).
LINK_OBJS := $(shell test -f out/main.link && cat out/main.link)

out/main.c out/main.link: main.kl $(REGS_KL) $(REGS_H) $(KLIN_SRCS)
	dart run $(KLIN) --emit-c main.kl

main.elf: board/linker.ld out/main.c out/main.link $(REGS_H) $(LINK_OBJS)
	$(CC) $(CFLAGS) -I. $(LDFLAGS) $$(cat out/main.link) out/main.c -o $@

ref: board/startup.s board/linker.ld ref/blink_ref.c $(REGS_H)
	$(CC) $(CFLAGS) -I. $(LDFLAGS) board/startup.s ref/blink_ref.c -o blink_ref.elf

clean:
	rm -rf out main.elf blink_ref.elf $(REGS_H) $(REGS_KL)
