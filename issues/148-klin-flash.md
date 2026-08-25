# 148 — `klin flash` (thin wrapper) vs board `make flash`

**Status:** 💭 backlog (not now)  
**Depends on:** [075](075-board-pack-init-host.md), [010](010-bare-metal.md); WeAct example [147](147-board-weact-f411.md)

## Verdict

| Question | Answer |
|---|---|
| Put a flasher **inside** the Klin compiler? | **No** — DFU / SWD / UF2 / IDF are host tools; cost must stay visible |
| `klin run … --flash` / `--emit-c --flash`? | **No** — `run` is host libc; emit is C only |
| Board `Makefile` `make flash`? | **Yes** — today’s UX ([147](147-board-weact-f411.md) `dfu-util`; ESP `idf.py`; Pico UF2 / picotool) |
| Optional later: `klin flash` as a **thin exec** of that Makefile (or a pin in `klin.mod`)? | 💭 maybe — UX sugar only, same argv the board already named |

Arduino “Upload” is not magic either: STM32duino calls `dfu-util` / CubeProgrammer. Klin already exposes the same step as `make flash`. A CLI alias does not remove BOOT0, probe choice, or tool install.

## Why not in the language / emit pipeline

Primary rule: no hidden allocation, control flow, or cost. Flashing is:

- board-specific (ROM DFU vs ST-Link vs UF2 vs `esptool` / IDF),
- interactive (BOOT0 + NRST on WeAct USB-C),
- outside the `.kl` → `.c` contract.

Baking it into `klin` as autodetection would hide which binary runs and which address is written.

## Allowed shapes (if ever)

### A — Status quo (preferred until pain is clear)

```sh
klin init weact-f411 my_pill
cd my_pill && klin get && make
make flash        # dfu-util …
make flash-swd    # st-flash …
```

Documented in [docs/embedded.md](../docs/embedded.md). Klin does not flash the chip.

### B — Thin CLI wrapper (optional)

```sh
klin flash           # → make flash  (cwd must be a scaffold with that target)
klin flash --swd     # → make flash-swd
```

Rules if implemented:

- **No** chip autodetection.
- **No** embedded DFU/SWD protocol in Dart.
- Only `exec` of an explicit board recipe (`make flash` or a single string from `klin.mod`).
- Fail loud if the tool (`dfu-util`, `st-flash`, `picotool`, `idf.py`) is missing.

### C — Separate helper name (`klinup` / `klinflash`)

Same as B, but as a **standalone script/binary** next to `klin` (or a tiny repo), so the compiler stay clearly “language + packages”. Naming is bikeshed; prefer `klin flash` subcommand over a second brand unless packaging forces a split.

## Out of scope

- Hiding flasher choice behind “Upload”.
- Flashing from `klin run` / host CRT.
- Replacing board Makefiles with a global Klin flash registry.
- USB CDC as Serial on WeAct (unrelated; USART stays explicit).

## Links

- WeAct scaffold + `make flash`: [147](147-board-weact-f411.md)
- Board pack / init: [075](075-board-pack-init-host.md)
- Bare metal: [010](010-bare-metal.md)
- Walkthrough: [docs/embedded.md](../docs/embedded.md)
