# 147 — Board scaffold: WeAct STM32F411CE Black Pill

**Status:** 🔨 `klin init weact-f411` (bundled template; no separate pin pack)  
**Depends on:** [061](061-micropython-machine-api.md), [075](075-board-pack-init-host.md), [096](096-board-nucleo-f411re.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **Allowlist only:** add `weact-f411` to `klin init` ([075](075-board-pack-init-host.md)) |
| Where does the code live? | Bundled `templates/weact-f411/` (startup + linker + blink + `make flash`) |
| Chip API | [`machine_stm32`](https://github.com/klin-lang/machine_stm32) `@v0.5.0` |
| Flash | **Not** in the compiler. Makefile runs `dfu-util` / `st-flash` — same tools STM32duino uses |

## Scope

- Freestanding blink on **PC13** (WeAct LED, active low)
- Same F411 memory map as Nucleo (512 K / 128 K)
- `make` → `main.elf`; `make flash` → ROM DFU; `make flash-swd` → ST-Link
- README: BOOT0 + USB-C is device USB, not ST-Link

**Out of scope:** USB CDC `Serial`, G-176 wiring examples (→ [`klin_st7735`](https://github.com/klin-lang/klin_st7735); SD/FatFs → [150](150-sd-spi-fatfs.md) / [`klin_sd_spi`](https://github.com/klin-lang/klin_sd_spi) + [`klin_fatfs`](https://github.com/klin-lang/klin_fatfs)), touch XPT2046 (→ [149](149-klin-xpt2046.md)), HSE 25 MHz PLL (HSI 16 MHz is enough), a published `weact_f411ce` pin pack (later, if needed). Black Pill shop pages listing **SDIO** mean the F411 peripheral — **not** an onboard microSD slot.

## Usage

```sh
klin init weact-f411 my_pill
cd my_pill
klin get
make
# hold BOOT0, tap NRST
make flash
```

## Links

- Template: [`templates/weact-f411/`](../templates/weact-f411/)
- Shop (example): [Elektroweb J-094](https://elektroweb.pl/pl/stm32/778-mikrokontroler-stm32f411ceu6-stm32-blackpill.html)
- Nucleo: [096](096-board-nucleo-f411re.md)
- `klin init`: [075](075-board-pack-init-host.md)
- Touch chip driver: [149](149-klin-xpt2046.md)
- SD / FatFs: [150](150-sd-spi-fatfs.md) — [`klin_sd_spi`](https://github.com/klin-lang/klin_sd_spi) + [`klin_fatfs`](https://github.com/klin-lang/klin_fatfs) `@v0.1.0`
