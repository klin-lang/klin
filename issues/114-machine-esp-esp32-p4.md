# 114 — `machine_esp` ESP32-P4 (Pin twin factories)

**Status:** ✅ published [`@v0.8.0`](https://github.com/klin-lang/machine_esp/releases/tag/v0.8.0) (Pin only)  
**Depends on:** [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** (emit C + ESP-IDF toolchain, same as C3/S3) |
| Where does the code live? | External: [`klin-lang/machine_esp`](https://github.com/klin-lang/machine_esp) |
| Pattern | Twin factories like S3 `*_s3` / RP `*_rp2350` — **no** shared `#ifdef` mega-driver |
| C3 / S3 | Unchanged: `pin_out` / `pin_out_s3` / … |
| P4 | Explicit: `pin_out_p4` / `pin_in_p4` |

P4 MMIO is **not** a copy of C3/S3 (`0x6000…`). GPIO / IO_MUX live in the
`0x500E…` band (IDF `soc` / TRM).

## What changed vs C3/S3 (MMIO, not ISA)

1. **Bases** — GPIO `0x500E0000`, IO_MUX `0x500E1000`  
2. **HP pads** — GPIO **0..54** (LP GPIO is a different controller — later)  
3. **Matrix** — `SIG_GPIO_OUT=256`, OEN_SEL bit **10** (same shape as S3, not C3)  
4. **GPIO ≥ 32** — `OUT1` / `ENABLE1` / `IN1`  
5. **Clock** — `GPIO_CLOCK_GATE` bit 0 (explicit in factory)  
6. **Examples** — `idf.py set-target esp32p4`

Dual RISC-V vs C3 RISC-V / S3 Xtensa is handled by **ESP-IDF**, not Klin.

## Scope

| Tag | Contents |
|---|---|
| [`@v0.8.0`](https://github.com/klin-lang/machine_esp/releases/tag/v0.8.0) | `pin_out_p4` / `pin_in_p4` + `examples/blink_p4` (default GPIO2; edit for board) |

`version()` → `8`.

## Out of scope (this tag)

- Pwm / Rc / Uart / I2c / Spi / Adc / Rmt `*_p4` — later additive tags  
- LP GPIO  
- RMII Ethernet — [`esp_eth`](https://github.com/klin-lang/esp_eth) [104](104-later-tracks-esp-network.md) **E1** (P4 preferred first RMII host; does not require more `machine_esp` P4 APIs)  
- On-die Wi‑Fi / BLE — **none** on P4 (companion / other host; not `esp_wifi` on P4 alone)  
- Freestanding (no IDF)  
- Board pack / `klin init` for a specific P4 module  
- Classic ESP32 / C6

## Usage

```klin
import "github/klin-lang/machine_esp" machine

let led = machine.pin_out_p4(2)
```

```sh
klin get github/klin-lang/machine_esp@v0.8.0
```

## Links

- Repo: https://github.com/klin-lang/machine_esp  
- PR: https://github.com/klin-lang/machine_esp/pull/8  
- Tag: [v0.8.0](https://github.com/klin-lang/machine_esp/releases/tag/v0.8.0)  
- Catalog: [061](061-micropython-machine-api.md), targets [062](062-targets-esp-rp.md)  
- S3 twin (same package): [099](099-machine-esp-esp32-s3.md)  
- RMII later: [102](102-esp-eth-idf.md) / [104](104-later-tracks-esp-network.md)
