# 156 — Board scaffold: LCKFB GD32VW553 (silk `GD32VW553HMQ-EVT`)

**Status:** 🔨 `klin init lckfb-gd32vw553` (bundled template; no separate pin pack)  
**Depends on:** [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md), [075](075-board-pack-init-host.md), [136](136-machine-gd32v-gd32vw553.md)

## Identification

Physical boards sold / labeled **`GD32VW553HMQ-EVT`** match the open **立创·GD32VW553** (LCKFB) stamp-hole module — **not** GigaDevice’s official START motherboard+module kit and **not** GD32VW553H-EVAL.

| Marker | What it means |
|---|---|
| Silk `GD32VW553HMQ-EVT` | Board / EVT breakout name |
| Chip **GD32VW553HMQ** | QFN40, up to **4096 KB** flash / **320 KB** SRAM (H-series) |
| Form factor | Dual 20-pin rows + castellated edges; ceramic chip antenna |
| USB-C | Onboard **CH340** (power + UART). **No** onboard GD-Link |
| Debug | Mid-board 6-pin JTAG: `3V3` / `TDO` / `TMS` / `TCK` / `TDI` / `GND` (needs external probe) |
| Buttons | `RESET`, `BOOT0`, user `KEY` |
| PWR LED | Power indicator only (not a GPIO blink target) |

`HMQ` alone names the **MCU package/SKU**, not the PCB. Always check silk / photo before picking a Klin scaffold.

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **Allowlist only:** add `lckfb-gd32vw553` to `klin init` ([075](075-board-pack-init-host.md)) |
| Where does the code live? | Bundled `templates/lckfb-gd32vw553/` (startup + linker + PC13 blink) — same pattern as [147](147-board-weact-f411.md) |
| Chip API | [`machine_gd32v`](https://github.com/klin-lang/machine_gd32v) `@v0.8.0` (`*_vw553`) |
| Official START pack | [139](139-board-gd32vw553h-start.md) — **wrong** LED/UART map for this PCB |
| Official EVAL pack | [138](138-board-gd32vw553h-eval.md) — COM0 USART0 PB15/PA8 matches CH340 here; **LED1 is PA4**, not PC13 |
| Wi‑Fi / BLE / sockets… | Same GD32VW553 radio packages ([137](137-gd32v-wifi-sdk.md), [140](140-gd32v-ble-sdk.md), …) once the wireless SDK is on the link path |

## Pin map (LCKFB wiki)

From [LCKFB VW553 docs](https://wiki.lckfb.com/zh-hans/gd32vw553/) (tutorials + schematic notes):

| Function | Pin | Notes |
|---|---|---|
| User LED | **PC13** | Active high in wiki examples; scaffold blink target |
| User KEY | **PA0** | Pulled down; press → high |
| Log / USB UART | **USART0** TX=**PB15** AF8 / RX=**PA8** AF2 | Routed to CH340 on USB-C |
| BOOT0 | **PC8** (chip) | Button on board; hold for ROM / UART download path |
| JTAG | PA15 / PA14 / PA13 / PB3 (+ PB4 NJTRST) | Broken out on the 6-pin header |

Do **not** assume START RGB (PB0 / PA12 / PB4) or EVAL LED1 (PA4) / UART2 (PA6/PA7).

## Scope

- Freestanding blink on **PC13** via `pin_out_vw553(Port.C, 13)`
- Linker map **4096K** flash / **320K** RAM (HMQ)
- `make emit` → C; `make elf` → `riscv64-unknown-elf-gcc`
- README: CH340 console, external JTAG, BOOT0 UART path

**Out of scope:** Published external pin pack (`lckfb_gd32vw553` later if needed), KEY/UART helpers in the scaffold, vendoring the wireless SDK, `make flash` (no onboard GD-Link — [148](148-klin-flash.md)).

## Usage

```klin
import "github/klin-lang/machine_gd32v" machine

@[link("board/startup.S")]
fn main() {
    let led = machine.pin_out_vw553(machine.Port.C, 13)
    led.toggle()
}
```

```sh
klin init lckfb-gd32vw553 my_stamp
cd my_stamp
klin get
make emit
make elf
```

## Flash / bring-up (hardware)

1. Power via USB-C (CH340 enumerates a COM port; install CH340 driver if needed).
2. Flash via **external JTAG** on the 6-pin header, or hold **BOOT0** + reset for UART download.
3. Console: 115200 8N1 on the CH340 port (USART0) once you add a UART app.
4. Klin does not flash the chip.

## Docs and downloads

### Board (LCKFB)

- Wiki hub: https://wiki.lckfb.com/zh-hans/gd32vw553/
- Environment / OpenOCD: https://wiki.lckfb.com/zh-hans/gd32vw553/beginner/environment-setup.html
- Download center (schematics / examples, Baidu): https://wiki.lckfb.com/zh-hans/gd32vw553/download-center.html
- OSHWHub project: https://oshwhub.com/li-chuang-kai-fa-ban/li-chuang-gd32vw553-kai-fa-ban
- Product page: https://lckfb.com/project/detail/lckfb-gd32vw553-hmq6

### Chip / official kits (GigaDevice)

- Download center (`GD32VW55`): https://www.gd32mcu.com/en/download?kw=GD32VW55
- Datasheet GD32VW553xx, User Manual, AN154 Quick Development Guide
- Wi‑Fi/BLE SDK: https://github.com/GigaDeviceSemiconductor/GD32VW55x_WiFi_BLE_SDK
- Closest official HMQ kit docs: **GD32VW553H-START Demo Suites** (UNIFI / H-series) — motherboard+module with GD-Link; pin map still differs from this stamp EVT

## Links

- Template: [`templates/lckfb-gd32vw553/`](../templates/lckfb-gd32vw553/)
- Chip MMIO: [136](136-machine-gd32v-gd32vw553.md) / [`machine_gd32v`](https://github.com/klin-lang/machine_gd32v)
- EVAL sibling: [138](138-board-gd32vw553h-eval.md)
- START sibling: [139](139-board-gd32vw553h-start.md)
- WeAct-style scaffold sibling: [147](147-board-weact-f411.md)
- `klin init` host: [075](075-board-pack-init-host.md)
- Embedded walkthrough: [../docs/embedded.md](../docs/embedded.md)
