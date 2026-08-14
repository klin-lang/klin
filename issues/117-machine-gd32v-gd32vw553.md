# 117 — `machine_gd32v` GD32VW553 (Pin… later twins)

**Status:** 🔨 Pin first (`pin_out_vw553` / `pin_in_vw553`)  
**Depends on:** [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md), [087](087-machine-gd32v.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | Same package: [`klin-lang/machine_gd32v`](https://github.com/klin-lang/machine_gd32v) |
| Pattern | Twin factories `*_vw553` — **no** shared `#ifdef` mega-driver |
| VF103 | Unchanged: `pin_out` / `pwm_out` / … ([087](087-machine-gd32v.md)) |
| VW553 | Explicit: `pin_out_vw553` / `pin_in_vw553` (this tag). Pwm…Adc later. |

VW553 MMIO is **not** a copy of VF103. VF103 is Nuclei **N205** with F1-style
GPIO (`CTL0`/`CTL1` @ `0x40010800`, RCU APB2 @ `0x40021000`). VW553 is Nuclei
**N307** @ 160 MHz with F4-style GPIO (`CTL` 2-bit/pin @ `0x40020000`, RCU
`0x40023800`). Ports **A..C** only (datasheet). On-die **Wi‑Fi 6 + BLE 5.2**
are **not** `machine_*` — later sibling packages over the GigaDevice VW55x
SDK (same split as [`esp_wifi`](https://github.com/klin-lang/esp_wifi) vs
`machine_esp`).

## What changed vs VF103 (MMIO, not ISA)

1. **GPIO** — `GPIOA` `0x40020000`, `GPIOB` `+0x400`, `GPIOC` `+0x800`. Registers:
   `CTL` `+0x00` (2 bits/pin: 00 in / 01 out / 10 AF / 11 analog), `OMODE` `+0x04`,
   `OSPD` `+0x08`, `PUD` `+0x0C`, `ISTAT` `+0x10`, `OCTL` `+0x14`, `BOP` `+0x18`
   (set `[15:0]`, clear `[31:16]`).
2. **RCU** — `0x40023800`. GPIO clocks: `RCU_AHB1EN` `+0x30` bits `PAEN=0`,
   `PBEN=1`, `PCEN=2`. Default IRC16M **16 MHz** (not VF103 IRC8M).
3. **Ports** — A..C, pins 0..=15 (package may bond fewer pads; edit the example).
4. **Core** — N307 (RV32IMAFDCPB). Blink examples stay polling; no ECLIC this tag.

Same `Pin` methods (`high` / `low` / `toggle` / `set` / `value`) as VF103 —
only the factory and register pointers differ.

## Scope (this tag)

- `pin_out_vw553` / `pin_in_vw553` + host `*_test.kl`
- Example `examples/blink_pa8_vw553/` (default PA8; edit for the board)
- `version()` bump on the package

## Out of scope (this tag)

- Pwm / Rc / Uart / I2c / Spi / Adc `*_vw553` (later tags, same package)
- Wi‑Fi / BLE (new packages, not `machine_gd32v`; not `esp_wifi`)
- Board pack / `klin init` for a VW553 module
- Full Nuclei / GigaDevice wireless SDK vendoring
- Combining with CH32V sources

## Usage

```klin
import "github/klin-lang/machine_gd32v" machine

fn main() {
    let led = machine.pin_out_vw553(machine.Port.A, 8)
    led.toggle()
}
```

Do **not** call `pin_out` (VF103) on a VW553.

## Links

- Package: https://github.com/klin-lang/machine_gd32v
- VF103 MVP: [087](087-machine-gd32v.md)
- Catalog: [061](061-micropython-machine-api.md), targets [062](062-targets-esp-rp.md)
