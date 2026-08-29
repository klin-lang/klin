# 075 — Board pack / `klin init` vs host (laptop): linker & startup

**Status:** 🔨 MCU `klin init` ✅ (`nucleo-f411`, `pico`, `pico2`, `waveshare-rp2350-lcd-096`, `waveshare-esp32-s3-pico`, `gd32vw553h-eval`, `gd32vw553h-start`, `lckfb-gd32vw553`, `weact-f411`; host-init still 💭)  
**Depends on:** [010](010-bare-metal.md), [054](054-embedded-project-layout.md), [053](053-device-board-assets.md); optionally [074](074-board-ioc-klin-mod.md)

## Verdict in brief

**Laptop (host): no magic — no `linker.ld`, `startup.s`, usually no Makefile either.**

`klin run examples/hello.kl` is enough: Klin emits C, calls host `gcc`/`clang`/`tcc`,
links with **CRT + libc**. No need for `linker.ld`, `startup.s`, or `make`.
Makefile / ld / startup is the **bare-metal** world (`examples/stm32/…`).

## Problem

`linker.ld` + `startup.s` is the biggest bare-metal entry barrier: memory map,
vector table, copying `.data`, zeroing `.bss`. A blink user should not
have to *understand or write* this — but Klin **does not hide** it in language magic
(principle: no hidden cost; [010](010-bare-metal.md)).

SVD / `$device` ([053](053-device-board-assets.md)) **does not generate** `.ld` or
startup — only MMIO / registers. Different layer.

## Conclusions (verdict)

### 1. Relief = pack + scaffold, not compiler

| Approach | Verdict |
|---|---|
| Generate `linker.ld` from SVD | ❌ no — SVD ≠ full linker map; debug becomes black box |
| Hide startup in “magic" Klin | ❌ no — [010](010-bare-metal.md) |
| Ready **board pack** (`startup.s` + `linker.ld` + optional pinout) | ✅ |
| **`klin init <board>`** (or repo template) copying pack | ✅ — [054](054-embedded-project-layout.md) |
| `board` directive / narrow `.ioc` (pinout) | later — [074](074-board-ioc-klin-mod.md); **does not** replace ld/startup |

UX goal: 95% of users **never edit** `linker.ld` / `startup.s`; they edit
`main.kl` + `$device` + optional pinout.

### 1b. Three relief layers on MCU (how it should look)

Not one magic — **three separate things**. GitHub fits layers A and C
(fetch like `require` / `device`); B is one-time local scaffold.

#### A — Board pack (ld + startup) — from GitHub

Repo / asset e.g. `github/…/board-nucleo-f411re` contains ready:

- `startup.s`, `linker.ld`, thin Makefile / rules,
- optional simple pin constants in `.kl`.

User: `klin get` (or Klin pack `require`) → files in cache / project.
**Does not write** ld/startup themselves. ARM build still explicit (Make + `arm-none-eabi`),
only boilerplate is **copied / from pack**, not invented by compiler.

#### B — `klin init nucleo-f411` — scaffold (not continuous fetch)

One-time project directory creation:

```text
my_blink/
  main.kl
  board/          # startup.s, linker.ld (from template / pack A)
  Makefile
  klin.mod        # device … (+ optional require board pack)
  README          # “run klin get first”
```

Template source may be **same GitHub pack (A)** or templates
in Klin distribution. Then work locally; `get` only pins versions —
init **does not** magically link on every build.

#### C — `board` in `klin.mod` + `$board` — pinout from `.ioc` ([074](074-board-ioc-klin-mod.md))

Later, separate from ld/startup:

```text
klin.mod:
  device github/…/stm32f411.svd main
  board  github/…/nucleo_f411re.ioc v0.1.0   # fetch like device → asset/
```

```klin
$device("github/…/stm32f411.svd", "RCC,GPIOA,STK")  // MMIO from SVD
$board("github/…/nucleo_f411re.ioc")                 // constants LED→PA5 etc.
```

- `klin get` downloads `.ioc` to `asset/` cache (seed); typical flow then
  **copies** to `board/*.ioc` in project — local file = truth, in git,
  **not** overwritten by `get`/`update` (details: [074](074-board-ioc-klin-mod.md)),
- parser extracts **pin map only** → constant codegen,
- **does not** generate `linker.ld` / `startup.s` — those still from A (pack) / B (init).

| Layer | Source | What user gets |
|---|---|---|
| A pack | GitHub (pack / asset) | `startup.s` + `linker.ld` (+ Make) |
| B init | template (often from A) | “buildable right away" directory |
| C `board`/`.ioc` | GitHub (asset, like SVD) | pin names — **not** linking |

**Work order:** A+B first (blink without ld pain), then C (easier
pinout from Cube). Host (laptop) outside this model entirely — see §3.

### 2. `linker.ld` differs per MCU (sometimes board)

- **Chip** — FLASH/RAM size and origin, sometimes regions (CCM, ITCM, …)
- **Board** — rarely (external flash, app offset vs bootloader)
- **Application** — rarely (dual-bank, custom layout)

That is **target / board** boilerplate, not a line in `klin.mod` next to `device`
(mod pins artifacts to fetch; ld lives in pack / `board/`).

### 3. Host (laptop) — **no** this magic and **no** these files

On laptop the path is `klin run` → emit C → host `gcc`/`clang`/`tcc` →
link with **system CRT + libc** (crt0, OS default linker script).

- **No** `startup.s` in host project.
- **No** `linker.ld` / `-T …` in typical `klin run`.
- **No** Makefile — build and run via **`klin run`** (or `klin test`).
- **No** freestanding interrupt vectors.

(Host exceptions with own Make — e.g. `ffi_add/` / `asm_add/` for C lib —
that is FFI, not requirement for ordinary program.)

That is not “the same problem as Nucleo". Host ≠ MCU; do not design bare-metal UX
as if every Klin program required ld/startup/Make.

| | Host | Bare-metal (STM32, …) |
|---|---|---|
| Build | `klin run` / `klin test` | Makefile (+ `arm-none-eabi-gcc`) |
| Entry / CRT | OS + toolchain | `startup.s` (vectors, Reset_Handler) |
| Linker script | host default | `linker.ld` (`-T`, FLASH/RAM) |
| User writes | `.kl` (+ optional `@[link]` to `.s`/`.a` FFI) | `.kl` + board pack (or manual boilerplate) |
| `klin init`? | optional light app template (`hello` + `klin.mod`) | **`klin init nucleo-f411`** (etc.) with `board/` + Make |

### 4. Two meanings of `klin init` (do not confuse)

1. **`klin init` (host)** — thin project: `main.kl`, optional empty/example
   `klin.mod`, no ld/startup. Nice-to-have; today copying
   `examples/hello.kl` is enough.
2. **`klin init <board>` (MCU)** — real relief for linker/startup pain:
   directory with `main.kl`, `board/{startup.s,linker.ld}`, thin Makefile,
   `klin.mod` with `device …`, README “run `klin get` first". Child /
   detail of [054](054-embedded-project-layout.md).

MCU-init implementation **after** layout settled in 054; host-init separately and
lower priority.

## Do not

- promise “Klin writes linker from chip by itself"
- mix host CRT with freestanding in one “magic" mode without explicit target
- full CubeMX → project ([074](074-board-ioc-klin-mod.md))
- HAL via pack — [031](031-hal-libraries.md)

## Criteria (when implementation lands)

- [x] documented split: host vs MCU (this issue + `examples/README`)
      — laptop: no magic, no `linker.ld`/`startup.s`/Makefile (`klin run`)
- [x] at least one board pack / Nucleo-F411 template without user editing ld
      — bundled `templates/nucleo-f411/` (`board/startup.s`, `board/linker.ld`, blink `main.kl`)
- [x] `klin init <board> [dir]` — scaffold from `templates/` (`lib/init.dart`, CLI)
- [x] additional boards: `pico`, `pico2`, `waveshare-rp2350-lcd-096`,
      `waveshare-esp32-s3-pico` (ESP-IDF scaffold; no freestanding ld/startup),
      `gd32vw553h-eval` (RISC-V freestanding + board pack [138](138-board-gd32vw553h-eval.md)),
      `gd32vw553h-start` (RISC-V freestanding + board pack [139](139-board-gd32vw553h-start.md)),
      `lckfb-gd32vw553` (RISC-V freestanding PC13 blink [156](156-board-lckfb-gd32vw553.md)),
      `weact-f411` (F411CE PC13 blink + `make flash` [147](147-board-weact-f411.md))
- [ ] (optional, low priority) `klin init` host → `hello` + mod

## Implementation notes

- Templates ship **in the Klin distribution** (`templates/<board>/`), not fetched
  from GitHub on every init (layer B in §1b). SVD / packages still via
  `klin get` + `klin.mod`.
- Known boards: `nucleo-f411` (STM32 + `$device` + local `.ioc`; optional pack
  [096](096-board-nucleo-f411re.md)), `pico` / `pico2`
  (`machine_rp` blink), `waveshare-rp2350-lcd-096` (backlight + board pack
  [095](095-board-waveshare-rp2350-lcd-096.md)), `waveshare-esp32-s3-pico`
  (ESP-IDF + D10 blink + board pack [100](100-board-waveshare-esp32-s3-pico.md)),
  `gd32vw553h-eval` (VW553 LED1 + board pack [138](138-board-gd32vw553h-eval.md)),
  `gd32vw553h-start` (VW553 RGB red + board pack [139](139-board-gd32vw553h-start.md)),
  `lckfb-gd32vw553` (LCKFB HMQ-EVT PC13 [156](156-board-lckfb-gd32vw553.md)),
  `weact-f411` (Black Pill PC13 + `dfu-util` [147](147-board-weact-f411.md)).
- ESP scaffolds use **IDF** (`main/app_main.c`, `sdkconfig.defaults`, `idf.py`)
  instead of `board/startup.s` + `linker.ld` — still layer B (one-time copy);
  packages via `klin get`.
- Discovery mirrors stdlib: repo `templates/`, `$KLIN_TEMPLATES`, or
  `templates/` / `share/klin/templates` beside the install (Homebrew `pkgshare`,
  release tarball). Formula + release workflow install the tree.
- CLI refuses a non-empty destination. Default dir = `./<board>`.
- Docs: [docs/06-cli.md](../docs/06-cli.md). Sibling demos:
  [`examples/stm32/device_f411/`](../examples/stm32/device_f411/),
  [`machine_rp` examples](https://github.com/klin-lang/machine_rp/tree/main/examples),
  [`waveshare_rp2350_lcd_096`](https://github.com/klin-lang/waveshare_rp2350_lcd_096),
  [`nucleo_f411re`](https://github.com/klin-lang/nucleo_f411re),
  [`adafruit_rp2040_can_feather`](https://github.com/klin-lang/adafruit_rp2040_can_feather)
  ([098](098-board-adafruit-rp2040-can-feather.md)),
  [`waveshare_esp32_s3_pico`](https://github.com/klin-lang/waveshare_esp32_s3_pico)
  ([100](100-board-waveshare-esp32-s3-pico.md)),
  [`gd32vw553h_eval`](https://github.com/klin-lang/gd32vw553h_eval)
  ([138](138-board-gd32vw553h-eval.md)),
  [`gd32vw553h_start`](https://github.com/klin-lang/gd32vw553h_start)
  ([139](139-board-gd32vw553h-start.md)),
  WeAct Black Pill (`klin init weact-f411`, [147](147-board-weact-f411.md)).

## Related

- [010](010-bare-metal.md) — startup stays `.s`; no magic in language
- [022](022-asm-libraries.md) — `@[link]`; `-T linker.ld` stays in Make
- [053](053-device-board-assets.md) — SVD / `$device` ≠ ld
- [054](054-embedded-project-layout.md) — `board/` layout + init sketch
- [074](074-board-ioc-klin-mod.md) — pinout / `.ioc`, not linker
