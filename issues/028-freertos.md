# 028 — Ergonomic FreeRTOS integration

**Status:** ✅ done (`klin_freertos` through `@v0.4.0` + blink + objdump vs C)
**Depends on:** 024, 010, 021, 022?; 026 welcome; 030 for `@[isr]`
**User map:** [docs/README.md](../docs/README.md) — RTOS = C kernel +
`klin_freertos` library, not a Klin scheduler.

Separate from general [024](024-rtos.md) (FFI + "C API client" — settled).

## Goal

Ergonomic Klin layer over FreeRTOS on a known port (e.g. Nucleo + F411),
without own scheduler and without hidden allocation.

- thin optional module / examples: task create, delay, queue, mutex, `FromISR`
- entry points: `@[codename("…")]` (010); stack/TCB/queue **explicit**
- vendor FreeRTOS as C alongside; optionally D3 (026) for patterns

## Shipped: `klin_freertos`

Package: [`github.com/klin-lang/klin_freertos`](https://github.com/klin-lang/klin_freertos)
(portable FreeRTOS C API client — not STM32-only; board HAL stays in `machine_*`).

| Piece | Status |
|---|---|
| FFI: `task_*` / `queue_*` / `semaphore_*` | ✅ `@v0.1.0` |
| `$rtos_task(name, stack, prio) { … }` | ✅ `@v0.2.0` (needs Klin path-import macros + `block`) |
| `FromISR` + `task_yield_from_isr` | ✅ `@v0.3.0` (with [030](030-isr-decorators.md) `@[isr]`) |
| smoke / emit-c stubs + `examples/from_isr/` | ✅ |
| Board blink (≥2 tasks + LED) | ✅ [`examples/stm32/freertos_blink/`](../examples/stm32/freertos_blink/) (emit-c / stubs always; `make elf FREERTOS_DIR=…` + `FreeRTOSConfig.h` for Nucleo) |
| Static create (no FreeRTOS heap) | ✅ `@v0.4.0` (`task_` / `queue_` / `semaphore_*_create_static`) |

```klin
import "github/klin-lang/klin_freertos" freertos

$rtos_task(blink, 512, 2) {
    while true {
        freertos.task_delay(100)
    }
}

fn main() {
    start_blink()
    freertos.task_start_scheduler()
}
```

Equivalently, without macro:

```klin
import "github/klin-lang/klin_freertos" freertos

@[codename("blink_task")]
fn blink_task(arg: *mut void) { … }

fn main() {
    let mut handle = freertos.null_ptr()
    freertos.task_create(blink_task, "blink", 512, freertos.null_ptr(), 2, &handle)
    freertos.task_start_scheduler()
}
```

### FromISR (✅ `@v0.3.0`)

Thin FFI — same names as FreeRTOS, no Hungarian prefix, **no auto-yield**:

| Klin | FreeRTOS |
|---|---|
| `queue_send_from_isr` / `queue_receive_from_isr` | `xQueueSendFromISR` / `xQueueReceiveFromISR` |
| `semaphore_give_from_isr` / `semaphore_take_from_isr` | `xSemaphoreGiveFromISR` / `xSemaphoreTakeFromISR` |
| `task_yield_from_isr` | `taskYIELD_FROM_ISR` |

Contract (prime rule):

- Pass `higher_priority_task_woken: *mut i32` (init with `pd_false()`).
- After FromISR calls, pass the flag **by value** to `task_yield_from_isr`.
- Combine with Klin `@[isr("Vector_Handler")]` ([030](030-isr-decorators.md)).

```klin
import "github/klin-lang/klin_freertos" freertos

@[isr("USART2_IRQHandler")]
fn usart2_irq() {
    let mut woken: i32 = freertos.pd_false()
    freertos.semaphore_give_from_isr(sem, &woken)
    freertos.task_yield_from_isr(woken)
}
```

Package pin: `klin get github/klin-lang/klin_freertos@v0.3.0`.
Stub smoke: `klin_freertos/examples/from_isr/`.

For cooperative async waiting on an IRQ **signal** inside an event-loop task,
[`eventloop`](https://github.com/klin-lang/eventloop) `@v0.4.0` offers
`flag_wait` ([029](029-async-event-loop.md)). That is **not** a substitute for
FromISR when waking / yielding a FreeRTOS task (idle/power).

### Static create (✅ `@v0.4.0`)

No FreeRTOS heap for the object — caller passes buffers as opaque `*mut void`
(sizes from the port headers). Needs `configSUPPORT_STATIC_ALLOCATION`.

- task: `StackType_t[stack_depth]` + `sizeof(StaticTask_t)`
- queue: item storage (`length × item_size` bytes) + `sizeof(StaticQueue_t)`
- semaphore: `sizeof(StaticSemaphore_t)`

| Klin | FreeRTOS |
|---|---|
| `task_create_static` | `xTaskCreateStatic` |
| `queue_create_static` | `xQueueCreateStatic` |
| `semaphore_create_mutex_static` | `xSemaphoreCreateMutexStatic` |
| `semaphore_create_binary_static` | `xSemaphoreCreateBinaryStatic` |

`$rtos_task` still expands to heap `task_create` — static stays an explicit call.
Package pin: `klin get github/klin-lang/klin_freertos@v0.4.0`.
Smoke: `klin_freertos/examples/static_create/`.

## `klin_freertos` library vs task "decorators" (settled)

Question: can external Klin lib (RTOS bindings, not stdlib — [024](024-rtos.md))
provide decorators to mark fn/methods as tasks?

**Attributes (`@[…]`) are handled by the compiler**,
not a `.kl` package. The library alone **cannot** add real `@[task]` if the frontend
does not know it (cf. ISR: [030](030-isr-decorators.md)).

What the lib **can** (without core magic):

| Mechanism | Realism |
|---|---|
| API + fn-pointer: `freertos.task_create(…)` | yes ✅ |
| `$…` macros (026) generating entry + registration | yes ✅ `$rtos_task` |
| `@[codename("…")]` on entry (like 010) | yes — already in language |
| Real `@[task(stack=…, prio=…)]` in checker/emit | only with compiler support |

**Methods as tasks:** FreeRTOS usually wants `void task(void*)` (C prototype), not
a method on `self`. Sensible: free `fn` + context in `arg`, optionally macro
generating wrapper.

Prime rule: decorator / macro **does not** hide TCB/stack allocation or
scheduler start — stack/TCB/prio stay explicit.

### Preferred ergonomics: macro in lib (not user-`@[…]`)

Tool in Klin: **`$…` macros ([026](026-preprocessor.md))** or explicit API.
`$rtos_task` is the chosen direction (shipped). Do **not** build a general
user-decorator system. Cf. ISR: [030](030-isr-decorators.md).

Event-loop in task: same macro approach — [029](029-async-event-loop.md)
(`$event_loop` ✅ `@v0.3.0`, nestable in `$rtos_task`).

## Mutexes / shared data (critical)

- multiple tasks + shared state = races, torn reads, deadlocks, priority
  inversion — **serious crises**, not edge case
- Klin **does not** hide synchronization: no magical "async-safe" or
  automatic locks on globals
- variants: explicit FFI `semaphore_take` / thin wrappers with visible cost;
  `FromISR` separately (✅ thin FFI above — still explicit)
- event-loop **does not replace** mutex between tasks
- prime rule: mutex = RTOS call / explicit section

## Other RTOS

Zephyr / RT-Thread: same FFI-client pattern possible later as separate packages.
**Not now** — see [024](024-rtos.md) (summary + deferral).

## Criteria

- [x] external package with task / delay / queue / mutex FFI
- [x] `$rtos_task` sugar without hidden alloc
- [x] `FromISR` FFI + explicit yield (no auto-yield) — `@v0.3.0`
- [x] `examples/stm32/freertos_blink/` — ≥2 tasks, delay, LED (Nucleo-F411RE)
- [x] static create FFI (no FreeRTOS heap for TCB/stack/queue/sem) — `@v0.4.0`
- [x] no overhead vs C+FreeRTOS — [`examples/stm32/freertos_blink/overhead.md`](../examples/stm32/freertos_blink/overhead.md)
  (`make compare`; `task_heartbeat` 12 B Klin = 12 B C, direct `vTaskDelay`)
