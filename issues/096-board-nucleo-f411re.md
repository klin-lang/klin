# 096 — Board pack: Nucleo-F411RE

**Status:** ✅ published `@v0.1.3`  
**Depends on:** [061](061-micropython-machine-api.md), [074](074-board-ioc-klin-mod.md), [075](075-board-pack-init-host.md), [010](010-bare-metal.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **Allowlist only:** `github/klin-lang/nucleo_f411re` for remote `$board("….ioc")` ([074](074-board-ioc-klin-mod.md)) |
| Where does the code live? | External: [`klin-lang/nucleo_f411re`](https://github.com/klin-lang/nucleo_f411re) `@v0.1.3` |
| Chip API | [`machine_stm32`](https://github.com/klin-lang/machine_stm32) `@v0.5.0` |
| Board extras | LD2/B1/VCP/I2C1/SPI2/A0 pin helpers + CubeMX `.ioc` seed + eight bare-metal examples |

## Scope (`@v0.1.3`)

- `nucleo_f411re/pins.kl` — `ld2_*`, `b1_*`, `vcp_*`, `i2c1_*`, `spi2_*`, `a0_*`, `hsi_hz()`
- `nucleo_f411re.ioc` — CubeMX pinout seed for `$board`
- Examples: `blink`, `uart_vcp`, `pwm_led`, `adc_pa0`, `button_b1`, `i2c1`, `spi2`, `rc_servo`
  (each with freestanding `startup.s` / `linker.ld` / Makefile)

`@v0.1.3`: `button_b1` uses Klin `&&` ([097](097-logical-ops.md)).

Not in this pack: HAL, Cube-generated `main`, hidden clocks, Freertos.

## Usage

```klin
import "github/klin-lang/machine_stm32" machine
import "github/klin-lang/nucleo_f411re" board

@[link("startup.s")]
fn main() {
  let led = machine.pin_out(cast(machine.Port, board.ld2_port()), board.ld2_pin())
  led.toggle()
}
```

```sh
klin get github/klin-lang/nucleo_f411re@v0.1.3
klin get github/klin-lang/machine_stm32@v0.5.0
```

Remote `.ioc` seed (after allowlist + `klin get` of the `.ioc` path):

```klin
$board("github/klin-lang/nucleo_f411re/nucleo_f411re.ioc")
```

Local project truth (preferred; `klin init nucleo-f411` ships this):

```klin
$board("board/nucleo_f411re.ioc")
```

## Scaffold

`klin init nucleo-f411` stays SVD + local `.ioc` (layer B). Optional next step:

```text
require github/klin-lang/nucleo_f411re v0.1.3
```

## Links

- Repo: https://github.com/klin-lang/nucleo_f411re  
- Tag: [v0.1.3](https://github.com/klin-lang/nucleo_f411re/releases/tag/v0.1.3)
- [074](074-board-ioc-klin-mod.md) — `$board` / `.ioc`
- [075](075-board-pack-init-host.md) — `klin init`
- Sibling board pack: [095](095-board-waveshare-rp2350-lcd-096.md)
