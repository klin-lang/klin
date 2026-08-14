# 123 — Map: FreeRTOS is C + `klin_freertos`, not the language

**Status:** ✅ done
**Depends on:** [116](116-docs-reorg.md), [024](024-rtos.md),
[028](028-freertos.md)

## Problem

Landing and idea say “no runtime / no scheduler in the language.”
`klin_freertos` already ships, but a reader only found it in `issues/`
and example READMEs. Same split as the event loop ([121](121-docs-async-lib.md)):
kernel = C, binding = package, not a Klin RTOS.

## Done

- [x] [docs/README.md](../docs/README.md) — Start-here row + sentence
- [x] [00-idea.md](../docs/00-idea.md) non-goal clarifies the split
- [x] [embedded.md](../docs/embedded.md) “Next” (not the `klin init` walkthrough)
- [x] [examples/README.md](../examples/README.md) remote/RTOS header
- [x] [028](028-freertos.md) points at the map

Landing README stays free of the package name.

## Out of scope

- A dedicated `docs/freertos.md`
- Scaffolding FreeRTOS in `klin init`
- Zephyr / RT-Thread packages
