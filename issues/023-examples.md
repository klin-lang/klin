# 023 — `examples/` directory

**Status:** ✅ done (seed + STM32 layout)
**Depends on:** current language state (001–012+)

## Goal

Directory **`examples/`** with short, runnable Klin programs —
not golden tests (`test/`), but material for learning and demos:

```bash
dart run bin/klin.dart run examples/hello.kl
```

## Layout

```
examples/
  README.md
  hello.kl, vec2.kl, slice_sum.kl, modules/
  stm32/
    blink_f411/     # Nucleo-F411RE — local SVD
    device_f411/    # same via $device + klin.mod (053)
```

- Host: `klin run examples/…`
- MCU: `examples/stm32/<name>/` + freestanding Makefile
- Further STM32 / FreeRTOS demos (028): also under `stm32/`

## Completion criteria

- [x] `examples/stm32/blink_f411/` (moved from `examples/blink_f411/`)
- [x] Makefile paths / ARM test updated
- [x] short `examples/README.md`

## What not to mix

- Do not replace `test/*.kl` — goldens stay in `test/`.
- A short language tutorial lives in [docs/guide.md](../docs/guide.md)
  (issue [116](116-docs-reorg.md)). This directory stays demos, not a book.
  A full language reference is still out of scope.

## Later

Cleaner demo layout / embedded scaffold (app vs board vs boilerplate):
[054](054-embedded-project-layout.md).
