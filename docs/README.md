# Klin documentation

How to read this tree. `note/` was renamed to `docs/` (issue 082) — do
not recreate it.

## Start here

| If you want… | Read |
|---|---|
| What Klin is, why C, who it is for | [../README.md](../README.md) (landing) then [00-idea.md](00-idea.md) |
| To write a small program | [guide.md](guide.md) (`if` / `defer` / `import` / precedence) |
| Blink on a board (`klin init`) | [embedded.md](embedded.md) |
| Typed MCU registers (SVD) | [device.md](device.md) |
| Runnable demos | [../examples/README.md](../examples/README.md) |
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
| [syntax.md](syntax.md) | Enums, `Type.fn`, destructuring |

`if` / `defer` / `import` and the operator table live in
[guide.md](guide.md) (§4, §6, §8, §9). Enums, `Type.fn`, and
destructuring: [syntax.md](syntax.md). Bitwise / logical operators:
[01-decisions.md](01-decisions.md) D8 / D9. Do not treat `issues/` as
the user guide.

## Tooling

| Doc | Topic |
|---|---|
| [05-fmt.md](05-fmt.md) | `klin fmt` |
| [06-cli.md](06-cli.md) | `run` / `test` / `get` / `--emit-c` / flags |
| [09-ffi-c.md](09-ffi-c.md) | `@[cimport]` / `@[cexport]` / `@[link]` |
| [10-asm.md](10-asm.md) | `.s` / `.S` via `@[link]` |
| [11-klin-libraries.md](11-klin-libraries.md) | `lib/`, `-I`, directory packages, remote imports |
| [17-homebrew.md](17-homebrew.md) | `brew install klin` |
| [19-debug.md](19-debug.md) | `#line`, `-g`, gdb / lldb |
| [08-time.md](08-time.md) | `stdlib/time` |

## Embedded and host builds

Host programs use `klin run` and libc. Bare-metal programs omit host
stdlib imports and use a board Makefile / `klin init`.

| Doc | Topic |
|---|---|
| [embedded.md](embedded.md) | `klin init` → `get` → `make` (Pico, STM32, ESP, …) |
| [device.md](device.md) | SVD → `$device` → zero-cost MMIO |
| [make.md](make.md) | Task, `dart compile exe`, when Make appears |
| [arduino.md](arduino.md) | Arduino-shaped boards (later track) |
| [../examples/stm32/](../examples/stm32/) | First freestanding demos (Nucleo / FreeRTOS) |
| [../templates/](../templates/) | `klin init` board trees (STM32, Pico, ESP32, …) |

STM32 is the **first** bare-metal proof, not the only target.
