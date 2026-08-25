# 150 — SD / FatFs later package (SPI card; SDIO separate)

**Status:** 💭 backlog (not now)  
**Depends on:** [061](061-micropython-machine-api.md), [021](021-c-libraries.md), [020](020-klin-libraries.md); LCD [`klin_st7735`](https://github.com/klin-lang/klin_st7735); touch [149](149-klin-xpt2046.md)

## Verdict

| Question | Answer |
|---|---|
| Fold SD into `klin_st7735`? | **No** — already deferred in that package’s README |
| Fold SD into `klin_xpt2046`? | **No** |
| Fold SD into `weact-f411` / Black Pill board scaffold? | **No** ([147](147-board-weact-f411.md)) |
| One package for “TFT + SD + touch”? | **No** — chip/protocol libs stay split ([149](149-klin-xpt2046.md)) |
| Where should SD live when built? | Separate external package (SPI block device + FatFs / `@[cimport]`), not `machine_*` magic |

## Two different “SD” surfaces

| Source | Hardware | Bus | Notes |
|---|---|---|---|
| 1.8″ TFT module slot (G-176 / msalamon-class) | microSD on the display PCB | **SPI** + `SD_CS` | Same SPI as LCD/touch with separate CS; keep unused CS HIGH |
| STM32F411 on Black Pill | **No slot on PCB** | **SDIO** peripheral on goldpins | Shop “SDIO” = chip feature; needs an external slot/breakout |

Filesystem (FatFs) can sit above either backend. SPI vs SDIO are separate low-level drivers.

## Scope when this track starts

1. **SPI SD block device** first (matches the TFT module slot).  
2. Thin FatFs (or equivalent) with **caller-owned buffers** — no hidden heap.  
3. Example: G-176 / msalamon module + Black Pill; `TFT_CS` / `T_CS` idle HIGH while talking to the card.  
4. **SDIO F411** later as a second backend (optional), not required for the TFT slot.

## Out of scope (this issue)

- Implementation in the compiler repo  
- Extending [147](147-board-weact-f411.md) blink scaffold  
- Pretending Arduino `SD.begin` / `File` exists in Klin today  

## Links

- Touch driver track: [149](149-klin-xpt2046.md)
- WeAct out-of-scope pointer: [147](147-board-weact-f411.md)
- `klin_st7735` G-176 example (SD_CS HIGH): https://github.com/klin-lang/klin_st7735/tree/main/examples/g176_blackpill
- µPython catalog mention: [061](061-micropython-machine-api.md) (`SD` / `SDCard` — inspiration only)
