# Nucleo-F411RE blink — remote `$device` + local `$board`

Same LED blink as [`../blink_f411/`](../blink_f411/), but the SVD comes from
the Klin asset cache (not `third_party/svd/`). Pin labels come from a local
CubeMX-style `.ioc` via `$board` ([074](../../../issues/074-board-ioc-klin-mod.md)).

## Layout ([054](../../../issues/054-embedded-project-layout.md))

```text
.
  main.kl
  board/
    startup.s, linker.ld
    nucleo_f411re.ioc   # project truth (not overwritten by klin get)
  Makefile
  klin.mod / klin.lock
```

## What

`klin.mod` pins a remote SVD; `main.kl` uses `$device(…)` plus
`$board("board/nucleo_f411re.ioc")` → `BoardPin.LD2` / `BoardPort.LD2`.

## Why

- [053](../../../issues/053-device-board-assets.md): `klin get` device assets
- [074](../../../issues/074-board-ioc-klin-mod.md): pinout from `.ioc` without HAL

## How

```sh
cd examples/stm32/device_f411
# once — reads klin.mod, fills $KLIN_CACHE/asset/… + klin.lock
dart run ../../../bin/klin.dart get
make
# → main.elf
```

`klin.mod`:

```
klin 1
device github/tinygo-org/stm32-svd/svd/stm32f411.svd main
```

## Links

- Local SVD sibling: [`../blink_f411/`](../blink_f411/)
- Scaffold: `klin init nucleo-f411`
- External board pack (pins + examples): [`nucleo_f411re`](https://github.com/klin-lang/nucleo_f411re) `@v0.1.3` — [096](../../../issues/096-board-nucleo-f411re.md)
- [docs/04-macros.md](../../../docs/04-macros.md)
- [issues/053](../../../issues/053-device-board-assets.md), [074](../../../issues/074-board-ioc-klin-mod.md), [054](../../../issues/054-embedded-project-layout.md)
- Board index: [`../README.md`](../README.md)
