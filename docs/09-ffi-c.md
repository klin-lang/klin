# C FFI — import and export (issues 021 / 045)

Interop with C is **explicit declarations** in Klin, not a header parser.

| Direction | Attributes | Example |
|---|---|---|
| **Import** C→Klin | `@[cimport]`, `@[cheader]`, `@[cinclude]`, `@[link]`, CLI `-l`/`-L` | [`examples/ffi_add/`](../examples/ffi_add/) |
| **Export** Klin→C | `@[cexport, codename("…")]` | [`examples/cexport_add/`](../examples/cexport_add/) |
| **ISR** (vector) | `@[isr("…")]` or `@[isr, codename("…")]` | [`examples/stm32/blink_f411/`](../examples/stm32/blink_f411/) |

Issues: [021](../issues/021-c-libraries.md) (import/link), [045](../issues/045-cexport.md) (export),
[030](../issues/030-isr-decorators.md) (ISR).

## Import (C → Klin)

```klin
@[cinclude("<math.h>")]
@[cimport, codename("sqrt")]
fn sqrt(x: f64): f64
```

- `@[cimport]` — function without body; frontend checks arity and types; emits C prototype
- `@[cheader]` — with `cimport`: declaration is in header (`cinclude`); **no** prototype in `.c`
  (needed for `static inline` from SVD / HAL)
- `@[codename("…")]` — C symbol (otherwise Klin mangling)
- `@[cinclude("…")]` — `#include` in emitted `.c` (quoted or `<…>`)

### Host builtins

Without declarations only **`puts`** and **`printf`** are allowed (varargs / historical
hello-world). Every other C function requires `@[cimport]`.

### Link

```klin
@[link("libadd.a")]          // path relative to .kl file
@[link("-lm")]               // linker flag as-is
```

CLI (host `klin run` / `klin test`):

```sh
klin run -L/opt/lib -lfoo main.kl
```

`@[link]` + `-l` / `-L` go to `gcc`/`clang`/`tcc` argv. With `--emit-c`
the `@[link]` list also goes to `out/<base>.link` (bare-metal Makefile);
non-flag paths that exist next to the declaring `.kl` are written as
**absolute** paths (so package cache `.c` / `.s` units link from any cwd).
Paths also cover ASM units (`.s` / `.S`) — [docs/10-asm.md](10-asm.md),
[`examples/asm_add/`](../examples/asm_add/).

C example: [`examples/ffi_add/`](../examples/ffi_add/).

## Export (Klin → C)

```klin
@[cexport, codename("klin_add")]
fn add(a: i32, b: i32): i32 {
    return a + b
}
```

- `@[cexport]` — `fn` **with body**; global symbol in C emission (not `static`)
- `@[codename("…")]` — **required** with `cexport` (stable name for C)
- Do not combine `cexport` with `cimport`; do not apply `cexport` to `main`

C calls the exported function by `codename`. Prototypes:

```sh
klin --emit-h lib.kl                 # → out/lib.h
klin --emit-c --emit-h lib.kl        # .c + .h
```

Example: [`examples/cexport_add/`](../examples/cexport_add/). Issue:
[046](../issues/046-emit-h.md).

## ISR (vector handlers)

**Not STM32-only.** `@[isr("…")]` works on any MCU whose startup / CRT exports a
C symbol for the IRQ. Klin emits that global function; the **vector table stays
in `.s` / vendor CRT** ([010](../issues/010-bare-metal.md)).

```klin
@[isr("SysTick_Handler")]   // string = exact linker symbol from your startup
fn systick_handler() {
    // short: toggle / flag / FromISR — no hidden prologue
}
```

- `@[isr("ExactVectorName")]` — preferred; implies `codename` (global C symbol)
- `@[isr, codename("…")]` — same with explicit `codename`
- Bare `@[codename("…")]` still works (010)
- Shape: free `fn`, no params, `void` / omitted return
- No `cimport` / `cexport` / `async` / `main`

### How to pick the name (any chip)

1. Open your **startup** (`.s` / `.S`) or vendor vector header and copy the
   handler symbol **character-for-character**.
2. Put that string in `@[isr("…")]`.
3. Link the same startup (`@[link("startup.s")]` or board Makefile / CRT).
4. Confirm with `nm` / `objdump` that the symbol is defined (not only referenced).

| Family (examples) | Typical symbol | Where to look |
|---|---|---|
| STM32 (CMSIS) | `SysTick_Handler`, `TIM2_IRQHandler` | `startup_*.s`, CMSIS |
| megaAVR / ATxmega | `USART_RX_vect`, `TIMER1_COMPA_vect` | avr-libc `ISR()` / vectors |
| RP2040 / RP2350 | e.g. IRQ handler names from pico-sdk / custom `.s` | SDK / your startup |
| ESP32-C3 | IDF / custom vector names | ESP-IDF or freestanding CRT |
| PIC16 (XC8) | depends on CRT / interrupt mode | XC8 docs / custom startup |

Wrong spelling → link error or a default weak handler (chip-dependent), not a Klin
runtime remap. Klin does **not** translate “TIM2” → symbol; you pass the final name.

Worked example (STM32): [`examples/stm32/blink_f411/`](../examples/stm32/blink_f411/).
Issue: [030](../issues/030-isr-decorators.md).

FreeRTOS ISR → task: use
[`klin_freertos`](https://github.com/klin-lang/klin_freertos) `@v0.3.0`
(`queue_*_from_isr` / `semaphore_*_from_isr` + explicit `task_yield_from_isr`)
with `@[isr("…")]` — no auto-yield ([028](../issues/028-freertos.md)).

ISR → event-loop `.await` (poll, not push-wake):
`@[isr]` calls [`eventloop`](https://github.com/klin-lang/eventloop) `@v0.4.0`
`flag_set` / `flag_clear` only; the async task uses `flag_wait(…).await`
([029](../issues/029-async-event-loop.md)). Does not replace FromISR for waking
a FreeRTOS task.

## Comparison

| | Import | Export | ISR |
|---|---|---|---|
| Marker | `@[cimport]` | `@[cexport]` | `@[isr("…")]` |
| Body in Klin | no | yes | yes |
| C name | usually `@[codename]` | **required** `@[codename]` | vector symbol |
| Typical use | libc / `.a` / HAL | Klin library | startup vector |

## Contract

FFI **does not** hide allocation or ownership — that is the user's agreement with C code.
Bare-metal: same declaration path; other libs (HAL → [031](../issues/031-hal-libraries.md)).
`.s` units → [docs/10-asm.md](10-asm.md) / [022](../issues/022-asm-libraries.md).
