# FreeRTOS blink — Klin vs C overhead (issue 028)

Same FreeRTOS-Kernel, `FreeRTOSConfig.h`, `CFLAGS`, linker script.
Klin: `main.kl` → `main.elf`. C twin: `ref/blink_ref.c` → `blink_ref.elf`.
(Snapshot paths below still say `blink.elf` — sizes from pre-layout rebuild.)

Generated: 2026-08-04T15:12Z

## `size` (whole ELF)

```
=== Klin (blink.elf) ===
   text	   data	    bss	    dec	    hex	filename
   3180	      4	  16652	  19836	   4d7c	blink.elf

=== C ref (blink_ref.elf) ===
   text	   data	    bss	    dec	    hex	filename
   3124	      4	  16652	  19780	   4d44	blink_ref.elf
```

## App symbol sizes (bytes, `nm -S`)

| Symbol | Klin | C ref |
|---|---:|---:|
| `task_blink` | 30 | 56 |
| `task_heartbeat` | 12 | 12 |
| `main` | 80 | 76 |

## `task_heartbeat` disassembly (pure RTOS delay loop)

Both should only call `vTaskDelay` in the loop — no Klin runtime.

### Klin

```
08000082 <task_heartbeat>:
 8000082:	b508      	push	{r3, lr}
 8000084:	f44f 707a 	mov.w	r0, #1000	@ 0x3e8
 8000088:	f000 fb64 	bl	8000754 <vTaskDelay>
 800008c:	e7fa      	b.n	8000084 <task_heartbeat+0x2>
	...

```

### C ref

```
080000bc <task_heartbeat>:
 80000bc:	b508      	push	{r3, lr}
 80000be:	f44f 707a 	mov.w	r0, #1000	@ 0x3e8
 80000c2:	f000 fb2b 	bl	800071c <vTaskDelay>
 80000c6:	e7fa      	b.n	80000be <task_heartbeat+0x2>

```

## Verdict

- FreeRTOS entry points are direct C calls (`vTaskDelay`, `xTaskCreate`,
  `vTaskStartScheduler`) — Klin FFI is thin `@[cimport]`, not a scheduler.
- `task_heartbeat` (fair RTOS-only compare): Klin=12 B, C=12 B —
  **equal** size; both disassemblies contain `vTaskDelay` (checked by compare.sh).
- `task_blink` may differ: Klin uses `machine_stm32.Pin` helpers; C ref
  inlines PA5 MMIO. That is board HAL shape, not FreeRTOS tax.
- Whole-ELF `.text`: Klin=3180, C=3124 (delta from Pin /
  thin wrappers; FreeRTOS kernel is shared).

Conclusion: **no hidden FreeRTOS / scheduler overhead** from Klin vs the C twin.
