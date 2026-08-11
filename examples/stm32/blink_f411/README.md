# Nucleo-F411RE blink — local SVD

Bare-metal LED blink on PA5 using a vendored SVD and `$peripherals_from_svd`.

## Layout ([054](../../../issues/054-embedded-project-layout.md))

```text
.
  main.kl           # app
  board/            # startup.s, linker.ld (same pack as other F411 demos)
  Makefile          # thin; includes ../_common/f411.mk
  ref/blink_ref.c   # optional C twin (`make ref`)
```

## What

`main.kl` toggles the Nucleo green LED. `svd2klin` generates register bindings
from `third_party/svd/stm32f411.svd`. `@[link("board/startup.s")]` feeds objects
into `out/main.link` for the Makefile.

## Why

Baseline board demo without remote assets — contrast with
[`../device_f411/`](../device_f411/) (`$device` + `klin.mod` / cache).

## How

Requires `arm-none-eabi-gcc` and Dart.

```sh
cd examples/stm32/blink_f411
make
# → main.elf
```

Optional C reference build: `make ref` → `blink_ref.elf`.

## Links

- Sibling (remote `$device`): [`../device_f411/`](../device_f411/)
- Scaffold: `klin init nucleo-f411`
- [docs/04-macros.md](../../../docs/04-macros.md)
- [issues/027](../../../issues/027-svd-ergonomic-api.md), [054](../../../issues/054-embedded-project-layout.md), [075](../../../issues/075-board-pack-init-host.md)
- Board index: [`../README.md`](../README.md)
