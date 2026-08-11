# Nucleo-F411RE FreeRTOS blink (issue 028 / 054 layout).
# Default: emit-c + arm-none-eabi object compile against freertos_stubs.
# Full ELF: make elf FREERTOS_DIR=/path/to/FreeRTOS-Kernel (uses FreeRTOSConfig.h here).
# Overhead: make compare FREERTOS_DIR=… → overhead.md (Klin vs ref/blink_ref.c).

include ../_common/f411.mk

CC := arm-none-eabi-gcc
CFLAGS := -mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=hard \
	-ffreestanding -Os -ffunction-sections -fdata-sections
# nano/nosys for memset and friends used by the FreeRTOS heap/TCB paths
LDFLAGS := -T board/linker.ld -Wl,--gc-sections -specs=nano.specs -specs=nosys.specs

KLIN ?= $(KLIN_ROOT)
STUB_INC := freertos_stubs

FREERTOS_DIR ?=

FREERTOS_SRCS := \
	$(FREERTOS_DIR)/tasks.c \
	$(FREERTOS_DIR)/queue.c \
	$(FREERTOS_DIR)/list.c \
	$(FREERTOS_DIR)/portable/MemMang/heap_4.c \
	$(FREERTOS_DIR)/portable/GCC/ARM_CM4F/port.c

FREERTOS_INC := -I. -I$(FREERTOS_DIR)/include -I$(FREERTOS_DIR)/portable/GCC/ARM_CM4F

LINK_OBJS := $(shell test -f out/main.link && cat out/main.link)

.PHONY: all clean emit elf ref compare

all: out/main.o
	@echo "ok: out/main.c out/main.o (stubs). For board ELF: make elf FREERTOS_DIR=…"

emit: out/main.c

out:
	mkdir -p out

out/main.c out/main.link: main.kl klin.mod klin.lock board/startup.s | out
	case "$(KLIN)" in \
	  *.dart) dart run "$(KLIN)" --emit-c main.kl ;; \
	  *) "$(KLIN)" --emit-c main.kl ;; \
	esac

out/main.o: out/main.c
	$(CC) $(CFLAGS) -c -I$(STUB_INC) -o out/main.o out/main.c

# Real kernel only — do NOT put freertos_stubs on -I (would shadow FreeRTOS.h).
main.elf: out/main.c out/main.link FreeRTOSConfig.h board/linker.ld $(LINK_OBJS)
	@test -n "$(FREERTOS_DIR)" || (echo "set FREERTOS_DIR to FreeRTOS-Kernel root"; exit 1)
	@test -f "$(FREERTOS_DIR)/include/FreeRTOS.h" || \
		(echo "FREERTOS_DIR missing include/FreeRTOS.h: $(FREERTOS_DIR)"; exit 1)
	$(CC) $(CFLAGS) $(FREERTOS_INC) $(LDFLAGS) \
		$$(cat out/main.link) out/main.c \
		$(FREERTOS_SRCS) \
		-o main.elf
	@echo "ok: main.elf"

elf: main.elf

# Hand-written C twin (same RTOS API surface as main.kl).
blink_ref.elf: ref/blink_ref.c board/startup.s FreeRTOSConfig.h board/linker.ld
	@test -n "$(FREERTOS_DIR)" || (echo "set FREERTOS_DIR to FreeRTOS-Kernel root"; exit 1)
	$(CC) $(CFLAGS) $(FREERTOS_INC) $(LDFLAGS) \
		board/startup.s ref/blink_ref.c \
		$(FREERTOS_SRCS) \
		-o blink_ref.elf
	@echo "ok: blink_ref.elf"

ref: blink_ref.elf

compare: main.elf blink_ref.elf
	chmod +x compare.sh
	./compare.sh main.elf blink_ref.elf overhead.md
	@echo "ok: overhead.md"

clean:
	rm -rf out main.elf blink_ref.elf
