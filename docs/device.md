# Device registers (SVD)

Typed MMIO from a CMSIS-SVD file. This is the MCU-side reason Klin
exists — not methods on structs. Host programs do not need it.

The compiler expands `$device` **before** parse. Fluent field access
lowers to the same `static inline` accessors `svd2klin` would emit.
If `objdump` shows a `bl` to `RCC_*` / `GPIOA_*`, the prime rule is
broken ([00-idea.md](00-idea.md)).

```klin
$device("github/tinygo-org/stm32-svd/svd/stm32f411.svd", "RCC,GPIOA,STK")

fn main() {
    RCC.AHB1ENR.GPIOAEN.set(1)
    GPIOA.MODER.MODER5.write(.Output)
    GPIOA.ODR.ODR5.toggle()
}
```

That must emit the same stores a human would write in C — a volatile
pointer, a mask, an OR. No helper call in the binary.

## Load an SVD

`$device` is a **vendor artifact**, not a Klin module. Do not write
`import "….svd"`.

```klin
// Remote (preferred UX) — cache after `klin get`
$device("github/tinygo-org/stm32-svd/svd/stm32f411.svd", "RCC,GPIOA,STK")

// Local path (relative to the .kl file)
$device("../../../third_party/svd/stm32f411.svd", "RCC,GPIOA,STK")

// Same builtin under the old name
$peripherals_from_svd("…", "RCC,GPIOA,STK")
```

- Top-level only (same family as `$fn`).
- Second argument: comma-separated peripheral names, or omit / `ALL`
  for the whole chip (large).
- Expand writes `{stem}_regs.h` and `{stem}_regs.kl` **next to the
  source** and splices `@[cinclude("…_regs.h")]`.

### Remote fetch

`klin run` / compile **never** downloads. Missing cache → error that
tells you to run `klin get`.

```
# klin.mod
klin 1
device github/tinygo-org/stm32-svd/svd/stm32f411.svd main
```

```sh
klin get          # fills $KLIN_CACHE/asset/… + klin.lock (commit + sha256)
```

`$device("github/…")` then resolves: local file → asset cache →
(only `klin get`) network. MVP allowlist:
`github/tinygo-org/stm32-svd`.

**Do not use raw vendor SVD by default.** ST (and others) ship files
that disagree with the TRM and the silicon. Klin follows TinyGo:
patched trees (`tinygo-org/stm32-svd` / stm32-rs), not the zip from
the vendor site. Wrong SVD looks like “the Klin is fine, the LED is
dead.”

Vendored copy used by the local-path example:
[`third_party/svd/`](../third_party/svd/).

## Fluent API

`PERIPH.REG.FIELD.method(…)` — names come from the SVD.

| Method | Meaning |
|---|---|
| `.set(n)` | write the field (OR / replace per generated inline) |
| `.write(n)` | write the field |
| `.write(.Enum)` | SVD `<enumeratedValues>` — `.Output` becomes the integer |
| `.toggle()` | XOR; **1-bit fields only**, no arguments |

Unknown `PERIPH.REG.FIELD` is a preprocess error. Read-only fields
have no writer. Inspect the expand:

```sh
klin --emit-pp path/to/main.kl
# → out/main.pp.kl   (accessors, no fluent)
```

The generated header next to the source is the C you would have typed.

## `$board` — pinout, not registers

`$device` is the **chip**. `$board` is a narrow CubeMX `.ioc` →
`BoardPort` / `BoardPin` enums (which pad is `LD2`). Not HAL, not
clocks, not a generated `main`.

```klin
$board("board/nucleo_f411re.ioc")
// BoardPin.LD2 == 5, BoardPort.LD2 == 0  → PA5 on Nucleo-F411RE
```

Local `board/*.ioc` is project truth. `klin get` of a remote `.ioc`
fills the asset cache and **does not** overwrite the local file.
Allowlist: `github/klin-lang/boards`,
[`nucleo_f411re`](https://github.com/klin-lang/nucleo_f411re).

Full board walkthrough (`klin init` → `make`) is still examples /
templates — not this page.

## What this is not

- **Not `import`.** Klin modules are `import geom`. SVD is `$device("…")`.
- **Not HAL / Cube / IDF.** Those stay C libraries + `@[cimport]`
  ([09-ffi-c.md](09-ffi-c.md), issue [031](../issues/031-hal-libraries.md)).
- **Not silent network.** Compile is offline once the cache exists.
- **Not full CubeMX.** `$board` is pin labels only
  ([074](../issues/074-board-ioc-klin-mod.md)).
- **Not STM32-only.** Any chip with a usable SVD can go through the
  same builtin. STM32F411 is the first proof; RP / ESP board packs
  use their own machine APIs where SVD is the wrong shape.

## Examples

| | |
|---|---|
| Local SVD | [`examples/stm32/blink_f411/`](../examples/stm32/blink_f411/) |
| Remote `$device` + `$board` | [`examples/stm32/device_f411/`](../examples/stm32/device_f411/) |
| Scaffold | `klin init nucleo-f411` → [`templates/nucleo-f411/`](../templates/nucleo-f411/) |

Issues (design, not the user page): [011](../issues/011-svd.md),
[027](../issues/027-svd-ergonomic-api.md),
[053](../issues/053-device-board-assets.md).
`$fn` macros in general: [04-macros.md](04-macros.md).
