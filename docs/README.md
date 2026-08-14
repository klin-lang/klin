# Klin documentation

How to read this tree. `note/` was renamed to `docs/` (issue 082) — do
not recreate it.

Landing and [00-idea.md](00-idea.md) explain **why** Klin. To go from
`hello` to a register to a small project **without** opening
`issues/`:

1. [guide.md](guide.md) — write Klin (`hello` → `if` / `defer` / `!T` → C)
2. [device.md](device.md) — typed register (`$device`, fluent MMIO)
3. [embedded.md](embedded.md) — small firmware project (`klin init` → `get` → `make`)

`issues/` is the roadmap, not this path.

## Start here

| If you want… | Read |
|---|---|
| What Klin is, why C, who it is for | [../README.md](../README.md) (landing) then [00-idea.md](00-idea.md) |
| To write a small program | [guide.md](guide.md) (`if` / `defer` / `import` / precedence) |
| Typed MCU registers (SVD) | [device.md](device.md) |
| Blink on a board (`klin init`) | [embedded.md](embedded.md) |
| Runnable demos | [../examples/README.md](../examples/README.md) |
| Talk to C / drop to ASM | [09-ffi-c.md](09-ffi-c.md), [10-asm.md](10-asm.md) — FFI and `asm("…")`, not a C/ASM language |
| Event loop | **Library** ([`eventloop`](https://github.com/klin-lang/eventloop)); `async` / `.await` are language sugar over it |
| RTOS / FreeRTOS | **Library** ([`klin_freertos`](https://github.com/klin-lang/klin_freertos)); kernel stays C |
| CLI / install details | [06-cli.md](06-cli.md), [17-homebrew.md](17-homebrew.md), [make.md](make.md) |
| What to build next | [../issues/sorted.md](../issues/sorted.md) — roadmap, not a manual |

## Design (why the language is this way)

| Doc | Role |
|---|---|
| [00-idea.md](00-idea.md) | Principle, C backend, neighbors, non-goals |
| [01-decisions.md](01-decisions.md) | D1–D9 (memory, errors, generics, …) |
| [02-architecture.md](02-architecture.md) | Pipeline and engineering rules Z1–Z6 |
| [03-name-license.md](03-name-license.md) | Name, `.kl`, MIT, generated C is yours |

## Language notes (reference, not a tutorial)

These are feature write-ups. The tutorial is [guide.md](guide.md).

| Doc | Topic |
|---|---|
| [04-macros.md](04-macros.md) | `$fn` preprocessor (D3) |
| [device.md](device.md) | `$device` / fluent MMIO from SVD |
| [07-interpolation.md](07-interpolation.md) | `"$name"` / `${expr}` → `printf` |
| [12-modules.md](12-modules.md) | `module` / `import` / `pub` |
| [13-fn-ptr.md](13-fn-ptr.md) | `fn(T…): Ret` (no capture) |
| [14-short-decl.md](14-short-decl.md) | `:=` → `let mut` |
| [14-allocator.md](14-allocator.md) | explicit `Allocator` (`stdlib/mem`) |
| [15-match.md](15-match.md) | `match` (no fallthrough) |
| [16-slice.md](16-slice.md) | `slice` / `slice_alloc` |
| [18-pick.md](18-pick.md) | `pick cond { a } { b }` → `?:` |
| [syntax.md](syntax.md) | Enums (incl. `table[Slot.B]`), `Type.fn`, destructuring |

`if` / `defer` / `import` and the operator table live in
[guide.md](guide.md) (§4, §6, §8, §9). Enums, `Type.fn`, and
destructuring: [syntax.md](syntax.md) (enum as `[N]T` index too).
Bitwise / logical operators:
[01-decisions.md](01-decisions.md) D8 / D9. Do not treat `issues/` as
the user guide.

The event loop is a **library**
([`eventloop`](https://github.com/klin-lang/eventloop)), not a language
runtime — no hidden scheduler. `async fn` / `.await` **are** language
(the compiler desugars them; a `.kl` file cannot invent `await`). They
need an explicit executor. The same lib works with plain `fn` callbacks
and no `async` ([029](../issues/029-async-event-loop.md),
[`examples/remote_eventloop/`](../examples/remote_eventloop/)).

RTOS is the same split: the kernel stays C;
[`klin_freertos`](https://github.com/klin-lang/klin_freertos) is a thin
FFI client, not a Klin scheduler. `$rtos_task` is a macro in that
package. Zephyr / RT-Thread are not packaged yet
([024](../issues/024-rtos.md), [028](../issues/028-freertos.md),
[`examples/stm32/freertos_blink/`](../examples/stm32/freertos_blink/)).

C and ASM stay **outside** the grammar. Talk to existing C with
`@[cimport]` / `@[cexport]` / `@[link]` — there is no `c("…")`
snippet ([09-ffi-c.md](09-ffi-c.md),
[`examples/ffi_add/`](../examples/ffi_add/),
[`examples/cexport_add/`](../examples/cexport_add/)). ASM is a
`.s` / `.S` unit on `@[link]`, or the `asm("…")` statement (emits
`asm volatile("…");` — a GNU string, not an assembler)
([10-asm.md](10-asm.md), [`examples/asm_add/`](../examples/asm_add/)).

## Tooling

| Doc | Topic |
|---|---|
| [05-fmt.md](05-fmt.md) | `klin fmt` |
| [06-cli.md](06-cli.md) | `run` / `test` / `get` / `--emit-c` / flags |
| [09-ffi-c.md](09-ffi-c.md) | `@[cimport]` / `@[cexport]` / `@[link]` |
| [10-asm.md](10-asm.md) | `.s` / `.S` via `@[link]`; `asm("…")` → `asm volatile` |
| [11-klin-libraries.md](11-klin-libraries.md) | `lib/`, `-I`, directory packages, remote imports |
| [17-homebrew.md](17-homebrew.md) | `brew install klin` |
| [19-debug.md](19-debug.md) | `#line`, `-g`, gdb / lldb |
| [08-time.md](08-time.md) | `stdlib/time` |

## Embedded and host builds

Host programs use `klin run` and libc. Bare-metal programs omit host
stdlib imports and use a board Makefile / `klin init`.

| Doc | Topic |
|---|---|
| [embedded.md](embedded.md) | `klin init` → `get` → `make` (Pico, STM32, ESP, VW553, …) |
| [device.md](device.md) | SVD → `$device` → zero-cost MMIO |
| [make.md](make.md) | Task, `dart compile exe`, when Make appears |
| [arduino.md](arduino.md) | Arduino-shaped boards (later track) |
| [../examples/stm32/](../examples/stm32/) | First freestanding demos (Nucleo / FreeRTOS) |
| [../templates/](../templates/) | `klin init` board trees (STM32, Pico, ESP32, VW553, …) |

STM32 is the **first** bare-metal proof, not the only target.
