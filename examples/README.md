# Examples

Runnable Klin demos (not golden tests — those live in `test/`).

Each **folder** has its own `README.md` with **What / Why / How / Links**.
Single-file `*.kl` demos are documented only in the tables below.

```sh
dart run bin/klin.dart run examples/hello.kl
dart run bin/klin.dart fmt examples/hello.kl          # stdout
dart run bin/klin.dart fmt -w examples/hello.kl       # write in place
dart run bin/klin.dart test examples/                 # *_test.kl
```

**Host (laptop):** ordinary `*.kl` and non-`stm32/` folders — **no** `linker.ld` /
`startup.s` (`klin run` + system CRT/libc). Make + ld + startup only for
bare-metal [`stm32/`](stm32/) ([075](../issues/075-board-pack-init-host.md)).
New MCU tree: `klin init <board> [dir]` copies `templates/<board>/`
(`main.kl` + `board/` + Makefile), then `klin get && make`.
Boards: `nucleo-f411`, `pico`, `pico2`, `waveshare-rp2350-lcd-096`
([075](../issues/075-board-pack-init-host.md)).

Style: [docs/05-fmt.md](../docs/05-fmt.md) (`klin fmt`). Sources with `$…` macros
are not valid Klin until expand — format `point.kl` (or `--emit-pp` output), not
`point_macro.kl` / `stm32/.../blink.kl` as-is.

## Host — single-file

| Path | Notes |
|---|---|
| `hello.kl` | Minimal `puts` |
| `vec2.kl` | Struct + methods |
| `point.kl` | `Vec2i` + `len_sq` (canonical Klin) |
| `point_macro.kl` | Same via `$fn` ([docs/04-macros.md](../docs/04-macros.md)) |
| `slice_sum.kl` | Arrays / slices |
| `fn_ptr.kl` | Function pointers without capture ([017](../issues/017-collection-methods.md) phase 2) |
| `slice_ops.kl` | `stdlib/slice` map/filter/reduce ([017](../issues/017-collection-methods.md), [docs/16](../docs/16-slice.md)) |
| `slice_alloc_demo.kl` | `stdlib/slice_alloc` + explicit `Allocator` ([017](../issues/017-collection-methods.md), [docs/16](../docs/16-slice.md)) |
| `short_decl.kl` | `:=` sugar for `let mut` ([055](../issues/055-short-decl.md), [docs/14](../docs/14-short-decl.md)) |
| `destructure.kl` | Destructuring `let { x, y } = p` / `let [a, b] = xs` ([056](../issues/056-destructuring.md)) |
| `multi_assign.kl` | Multi-assignment / swap `a, b = b, a` ([056](../issues/056-destructuring.md)) |
| `match.kl` | `match` stmt + expr, no fallthrough ([014](../issues/014-match.md), [docs/15](../docs/15-match.md)) |
| `add_test.kl` | Sample `klin test` (`import testing`) |
| `interp.kl` | String interpolation → `printf` ([docs/07-interpolation.md](../docs/07-interpolation.md)) |
| `time_demo.kl` | `stdlib/time` — Instant / Duration / format ([docs/08-time.md](../docs/08-time.md)) |
| `mem_heap.kl` | `stdlib/mem` — explicit `Allocator` heap ([docs/14-allocator.md](../docs/14-allocator.md)) |
| `str_eq.kl` | `stdlib/str` |
| `math_basic.kl` | `stdlib/math` |
| `bitwise.kl` | Bitwise operators |
| `logical.kl` | Logical operators (`&&` / `||`) |
| `enums.kl` | Enums ([072](../issues/072-enums.md)) |
| `associated_fn.kl` | Associated functions |
| `number_literals.kl` | Binary / exponent literals ([081](../issues/081-number-literals.md)) |
| `sketch_async_eventloop.kl` | `async`/`await` + remote eventloop ([029](../issues/029-async-event-loop.md); also [`remote_eventloop/`](remote_eventloop/)) |

## Host — folders

| Path | Notes |
|---|---|
| [`ffi_add/`](ffi_add/) | Host C `.a` via `@[cimport]` + `@[link]` |
| [`cexport_add/`](cexport_add/) | Klin → C via `@[cexport, codename]` |
| [`asm_add/`](asm_add/) | Host `.S` via `@[link]` + `@[cimport]` |
| [`klin_lib/`](klin_lib/) | `lib/` + `-I` / `$KLIN_PATH` |
| [`pkg_geom/`](pkg_geom/) | Directory = one module |
| [`modules/`](modules/) | File-per-module `import` / `pub` |

## Remote packages & RTOS sketches

| Path | Notes |
|---|---|
| [`remote_osa/`](remote_osa/) | `klin get` + `import "github/klin-lang/osa"` ([049](../issues/049-remote-imports.md)) |
| [`remote_eventloop/`](remote_eventloop/) | Host eventloop callbacks + async (manual `init`/`run`; [029](../issues/029-async-event-loop.md)) |
| [`remote_eventloop_macro/`](remote_eventloop_macro/) | Same via `$event_loop` (`eventloop@v0.3.0`) |
| [`freertos_eventloop/`](freertos_eventloop/) | FreeRTOS + eventloop callbacks (emit-c / stubs; [029](../issues/029-async-event-loop.md) phase 3) |
| [`freertos_eventloop_async/`](freertos_eventloop_async/) | Same with `async` / `spawn` / `sleep_ms` |
| [`freertos_eventloop_macro/`](freertos_eventloop_macro/) | FreeRTOS + `$rtos_task` + `$event_loop` (callbacks + async) |

## Bare-metal

| Path | Notes |
|---|---|
| [`stm32/`](stm32/) | Board pack index — `main.kl` + `board/` layout ([054](../issues/054-embedded-project-layout.md)) |
| [`stm32/blink_f411/`](stm32/blink_f411/) | Nucleo-F411RE — local SVD |
| [`stm32/device_f411/`](stm32/device_f411/) | Same via `$device` + `klin get` ([053](../issues/053-device-board-assets.md)) |
| [`stm32/freertos_blink/`](stm32/freertos_blink/) | FreeRTOS ≥2 tasks + PA5 LED (`klin_freertos` + `machine_stm32`; [028](../issues/028-freertos.md)) |
