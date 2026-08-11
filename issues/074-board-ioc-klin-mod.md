# 074 — `board` in `klin.mod` + narrow CubeMX `.ioc` (pinout)

**Status:** ✅ MVP (`board` + `$board` + local `.ioc`; remote allowlist ready)  
**Depends on:** [053](053-device-board-assets.md) (`$device` + `device` in mod + `asset/` cache); optionally [054](054-embedded-project-layout.md); **not** [031](031-hal-libraries.md)

## Context

[053](053-device-board-assets.md) = chip / SVD (`device` + `$device`).  
This issue = **board / pinout** via CubeMX **`.ioc`**.

- single **`klin.mod`** file (not separate `klin.hw` / `klin.dev`)
- **`board`** directive (not `hardware`, not `device`)
- IOC scope = **pin map only**, not full Cube
- ld / startup **not** from IOC — from board pack / `klin init` (layers A+B in
  [075 §1b](075-board-pack-init-host.md); this issue = layer C)

## Example `klin.mod`

```text
klin 1
require  github/klin-lang/osa v0.1.0
device   github/tinygo-org/stm32-svd/svd/stm32f411.svd main
board    github/klin-lang/nucleo_f411re/nucleo_f411re.ioc v0.1.3
```

| Directive | Artifact | Code |
|---|---|---|
| `require` | Klin package (`.kl`) | `import` |
| `device` | chip SVD (`.svd`) — [053](053-device-board-assets.md) | `$device("…")` |
| `board` | board / pinout (`.ioc`) | `$board("…")` |

## Source syntax

```klin
$device("github/tinygo-org/stm32-svd/svd/stm32f411.svd", "RCC,GPIOA,STK")
$board("board/nucleo_f411re.ioc")

fn main() {
  // BoardPin.LD2 / BoardPort.LD2 from .ioc (PA5)
  GPIOA.MODER.MODER5.write(.Output)
}
```

- `$` family (D3); **not** `import "*.ioc"`
- same `klin get` / `asset/` cache / `klin.lock` as SVD; **different** parser after fetch
- Codegen: `enum BoardPort: i32` + `enum BoardPin: i32` (labeled GPIOs only)

## Local `.ioc` in project (verdict)

After editing in Cube / manually **`.ioc` belongs to the project** — goes in git.
Remote/`klin.mod` **must not** overwrite it on ordinary `get` / `update`.

| Source | Role |
|---|---|
| Cache after `klin get …ioc@ref` | upstream / seed |
| File in project (`board/*.ioc`) | **editable source of truth**; committed |

Flow:

1. **Local only** — `$board("board/nucleo.ioc")`; no `board github/…` line
   (or line only as documentation “where it came from").
2. **Remote as seed** — `klin get` → cache only; copy into `board/*.ioc` is a
   one-time scaffold / manual step (`klin init` ships a local `.ioc`).
3. **`klin update` does not overwrite** local `.ioc`.

Resolution like SVD ([053](053-device-board-assets.md)): **local-first**.

## Criteria

- [x] `board` directive in `klin.mod` parser + lock
- [x] `$board("…")` locally, then remote path (local-first)
- [x] local `.ioc` in project not overwritten by `get`/`update`
- [x] **subset** `.ioc` parser → pin constants (name → port/pin)
- [x] zero HAL / clock tree / generated `main` from Cube
- [x] e2e: Nucleo `.ioc` → `BoardPin.LD2` / `BoardPort.LD2`;
      [`examples/stm32/device_f411/`](../examples/stm32/device_f411/) +
      `templates/nucleo-f411/board/nucleo_f411re.ioc`
- [x] docs: “does not replace Cube”; local truth vs upstream

## Implementation notes

- `lib/ioc/` — parse / emit / expand
- Allowlist: `github/klin-lang/boards`,
  [`github/klin-lang/nucleo_f411re`](https://github.com/klin-lang/nucleo_f411re)
  (board pack + `.ioc` seed — [096](096-board-nucleo-f411re.md))
- Fixture: [`third_party/ioc/nucleo_f411re.ioc`](../third_party/ioc/nucleo_f411re.ioc)

## Do not

- full CubeMX → Klin project
- confuse with `device` (SVD) or `require` (`.kl` lib)
- silent download on `run`
- **`klin get`/`update` overwriting** local, edited `.ioc` in project
- HAL via IOC — [031](031-hal-libraries.md)

## Related

- [053](053-device-board-assets.md) — `$device` / `device` (chip)
- [049](049-remote-imports.md) / [065](065-project-lockfile.md) — get / lock
- [054](054-embedded-project-layout.md) — `board/` layout (startup/ld) separate from mod
- [075](075-board-pack-init-host.md) — board pack / `klin init` (ld+startup)
- [031](031-hal-libraries.md) — HAL separately
