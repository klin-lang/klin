# 129 — Board pack: GD32VW553 START

**Status:** 🔨 published [`@v0.1.0`](https://github.com/klin-lang/gd32vw553h_start/releases/tag/v0.1.0)  
**Depends on:** [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md), [075](075-board-pack-init-host.md), [117](117-machine-gd32v-gd32vw553.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **Allowlist only:** add `gd32vw553h-start` to `klin init` ([075](075-board-pack-init-host.md)) |
| Where does the code live? | External: [`klin-lang/gd32vw553h_start`](https://github.com/klin-lang/gd32vw553h_start) `@v0.1.0` |
| Chip API | [`machine_gd32v`](https://github.com/klin-lang/machine_gd32v) `@v0.8.0` (`*_vw553`) |
| Board extras | START RGB / UART2 log pin helpers + freestanding blink / uart_log examples |

## Scope (`@v0.1.0`)

- `pins.kl` — `led_r_*` PB0, `led_g_*` PA12, `led_b_*` PB4 (AN154 **V4.0 / V4.1** RGB); `log_*` UART2 TX=PA6 AF10 / RX=PA7 AF8 (GigaDevice SDK `uart.h` / `uart_config.h`); `irc16m_hz()`
- Examples: `blink` (red), `uart_log` (UART2 / GDLINK VCP)
- Covers H-START and K-START for this map (same UART2 + V4 RGB). Older V3.0 RGB PB11/12/13 is **not** mapped.

**Out of scope:** EVAL pack (→ [127](127-board-gd32vw553h-eval.md)), Wi‑Fi API (→ [`gd32v_wifi`](https://github.com/klin-lang/gd32v_wifi) [126](126-gd32v-wifi-sdk.md)), BLE, user key (AN154 SW1 is NRST only), V3.0 LED map, vendoring the wireless SDK.

**Scaffold:** `klin init gd32vw553h-start` — freestanding RGB-red blink via
bundled `templates/gd32vw553h-start/` ([075](075-board-pack-init-host.md)).

Nuclei SDK has EVAL only — no `gd32vw553*_start` header. Pins come from
AN154 + [`GD32VW55x_WiFi_BLE_SDK`](https://github.com/GigaDeviceSemiconductor/GD32VW55x_WiFi_BLE_SDK)
(`CONFIG_BOARD` default = `PLATFORM_BOARD_32VW55X_START`).

## Usage

```klin
import "github/klin-lang/machine_gd32v" machine
import "github/klin-lang/gd32vw553h_start" board

@[link("startup.S")]
fn main() {
    let led = machine.pin_out_vw553(cast(machine.Port, board.led_r_port()), board.led_r_pin())
    led.toggle()
}
```

```sh
klin get github/klin-lang/gd32vw553h_start@v0.1.0
klin get github/klin-lang/machine_gd32v@v0.8.0
klin init gd32vw553h-start my_blink
```

## Links

- Repo: https://github.com/klin-lang/gd32vw553h_start  
- Tag: [v0.1.0](https://github.com/klin-lang/gd32vw553h_start/releases/tag/v0.1.0)  
- AN154 GD32VW553 Quick Development Guide (GigaDevice)  
- SDK UART: [`uart.h`](https://github.com/GigaDeviceSemiconductor/GD32VW55x_WiFi_BLE_SDK/blob/main/MSDK/plf/src/uart/uart.h)  
- Chip: [117](117-machine-gd32v-gd32vw553.md) / [`machine_gd32v`](https://github.com/klin-lang/machine_gd32v)  
- EVAL sibling: [127](127-board-gd32vw553h-eval.md) / [`gd32vw553h_eval`](https://github.com/klin-lang/gd32vw553h_eval)  
- Radio sibling: [126](126-gd32v-wifi-sdk.md) / [`gd32v_wifi`](https://github.com/klin-lang/gd32v_wifi)  
- `klin init`: [075](075-board-pack-init-host.md)
