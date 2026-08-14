# 138 — Board pack: GD32VW553H-EVAL

**Status:** 🔨 published [`@v0.1.0`](https://github.com/klin-lang/gd32vw553h_eval/releases/tag/v0.1.0)  
**Depends on:** [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md), [075](075-board-pack-init-host.md), [136](136-machine-gd32v-gd32vw553.md)
**Formerly:** `127` (renumbered to resolve duplicate issue numbers).

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **Allowlist only:** add `gd32vw553h-eval` to `klin init` ([075](075-board-pack-init-host.md)) |
| Where does the code live? | External: [`klin-lang/gd32vw553h_eval`](https://github.com/klin-lang/gd32vw553h_eval) `@v0.1.0` |
| Chip API | [`machine_gd32v`](https://github.com/klin-lang/machine_gd32v) `@v0.8.0` (`*_vw553`) |
| Board extras | EVAL LED/KEY/COM0/I2C0 pin helpers + freestanding blink/uart/button examples |

## Scope (`@v0.1.0`)

- `pins.kl` — `led1_*`…`led3_*` (PA4/PA5/PA6), `key_*` (PA0), `com0_*` (USART0 TX=PB15 AF8 / RX=PA8 AF2), `i2c0_*` (PA2/PA3 AF2), `irc16m_hz()`
- Examples: `blink` (LED1), `uart_com0`, `button_key`
- Pin macros match Nuclei SDK `gd32vw553h_eval.h`

**Out of scope:** START kit (→ [139](139-board-gd32vw553h-start.md) / [`gd32vw553h_start`](https://github.com/klin-lang/gd32vw553h_start); SDK default UART2 PA6/PA7), Wi‑Fi API (→ [`gd32v_wifi`](https://github.com/klin-lang/gd32v_wifi) [137](137-gd32v-wifi-sdk.md)), BLE, SPI helpers (those pads overlap the LEDs), board pack for VF103 Longan Nano, vendoring the wireless SDK.

**Scaffold:** `klin init gd32vw553h-eval` — freestanding LED1 blink via
bundled `templates/gd32vw553h-eval/` ([075](075-board-pack-init-host.md)).

## Usage

```klin
import "github/klin-lang/machine_gd32v" machine
import "github/klin-lang/gd32vw553h_eval" board

@[link("startup.S")]
fn main() {
    let led = machine.pin_out_vw553(cast(machine.Port, board.led1_port()), board.led1_pin())
    led.toggle()
}
```

```sh
klin get github/klin-lang/gd32vw553h_eval@v0.1.0
klin get github/klin-lang/machine_gd32v@v0.8.0
klin init gd32vw553h-eval my_blink
```

## Links

- Repo: https://github.com/klin-lang/gd32vw553h_eval  
- Tag: [v0.1.0](https://github.com/klin-lang/gd32vw553h_eval/releases/tag/v0.1.0)  
- Nuclei board: [GD32VW553H Evaluation Kit](https://doc.nucleisys.com/nuclei_sdk/design/board/gd32vw553h_eval.html)  
- Header: [`gd32vw553h_eval.h`](https://github.com/Nuclei-Software/nuclei-sdk/blob/master/SoC/gd32vw55x/Board/gd32vw553h_eval/Include/gd32vw553h_eval.h)  
- Chip: [136](136-machine-gd32v-gd32vw553.md) / [`machine_gd32v`](https://github.com/klin-lang/machine_gd32v)  
- Radio sibling: [137](137-gd32v-wifi-sdk.md) / [`gd32v_wifi`](https://github.com/klin-lang/gd32v_wifi) [`@v0.4.0`](https://github.com/klin-lang/gd32v_wifi/releases/tag/v0.4.0)  
- `klin init`: [075](075-board-pack-init-host.md)
