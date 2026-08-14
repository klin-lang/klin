# 130 — GD32VW553 BLE as a separate SDK package (`gd32v_ble`)

**Status:** 🔨 advertise published [`@v0.1.0`](https://github.com/klin-lang/gd32v_ble/releases/tag/v0.1.0) (GATT / central later)  
**Depends on:** [021](021-c-libraries.md), [024](024-rtos.md), [049](049-remote-imports.md), [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md), [117](117-machine-gd32v-gd32vw553.md), [126](126-gd32v-wifi-sdk.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | External: [`klin-lang/gd32v_ble`](https://github.com/klin-lang/gd32v_ble) `@v0.1.0` |
| Engine | **GigaDevice VW55x BLE SDK** (AN152 stack + `MSDK/ble/app` managers) — not MMIO, **not** ESP-IDF NimBLE |
| Relation to `machine_gd32v` | **Separate.** Pin…Adc twins stay MMIO ([117](117-machine-gd32v-gd32vw553.md)). Same split as [`esp_ble`](https://github.com/klin-lang/esp_ble) vs `machine_esp` ([106](106-esp-ble-idf.md)). |
| Relation to `gd32v_wifi` | Sibling radio package ([126](126-gd32v-wifi-sdk.md)). Not the same Klin module. |

## Why not `machine_gd32v.Ble`?

[`machine_gd32v`](https://github.com/klin-lang/machine_gd32v) is thin Klin over **explicit MMIO**. VW553 BLE needs the GigaDevice wireless SDK (BLE task, GAP, RF blobs). Folding that into `machine_*` would hide SDK heap / tasks and break the MMIO contract.

Do **not** vendor the full SDK. The example expects
[`GD32VW55x_WiFi_BLE_SDK`](https://github.com/GigaDeviceSemiconductor/GD32VW55x_WiFi_BLE_SDK)
on the include/link path (AN152). Do **not** use [`esp_ble`](https://github.com/klin-lang/esp_ble) on VW553 (wrong engine).

Klin C glue calls the SDK **app** managers (`ble_init` / `app_adp_set_name` /
`app_adv_create` in `MSDK/ble/app/`), which wrap the AN152 stack exports
(`ble_adv_create` / `ble_adv_stop` in `MSDK/blesw/src/export/`).
`BLE_GAP_ADV_PROP_UNDIR_CONN` is GigaDevice `ble_gap.h`, not NimBLE.

## Scope (`@v0.1.0` — advertise)

- `init` — `ble_init(true)` + `ble_wait_ready` (once)  
- `advertise(name)` — `app_adp_set_name` + `app_adv_create` (wraps `ble_adv_create`) legacy undirected connectable (`BLE_GAP_ADV_PROP_UNDIR_CONN` in GigaDevice `ble_gap.h`)  
- `wait_connected(timeout_ms)` — host stub succeeds after `advertise`; on-device polls a flag (`-1` = forever). GAP connect event hook later  
- `connected` / `advertising` — `i32` 1/0  
- `stop_advertise` / `stop` — `app_adv_stop` / `ble_deinit`  
- `err_ok` / `version()` → `1`  
- Implementation: `@[link("ble_sdk.c")]` + `@[cimport]` (no `@[cinclude]`)  
- Host tests use the C file **without** SDK headers (`__has_include` stubs)  
- Example `examples/advertise/` — needs the official SDK to link an ELF  

## Out of scope (this tag)

- GATT server / client / notify  
- Central scan + connect  
- Bonding / passkey / privacy / Mesh  
- Wi‑Fi — [`gd32v_wifi`](https://github.com/klin-lang/gd32v_wifi) [126](126-gd32v-wifi-sdk.md)  
- Board packs — [127](127-board-gd32vw553h-eval.md) / [129](129-board-gd32vw553h-start.md) (no radio API)  
- Vendoring `GD32VW55x_WiFi_BLE_SDK`  
- Using [`esp_ble`](https://github.com/klin-lang/esp_ble) on VW553  

## Contract (prime rule)

- No Klin GC / hidden heap — advertise name is a C string you pass in.  
- SDK heap / OSAL BLE task / GAP events are **SDK contracts**, documented in the package README.  
- Errors are `i32` (0 = ok).  
- Host `klin test` must not require the SDK tree.

## Usage

```klin
import "github/klin-lang/gd32v_ble" ble

fn main() {
    let mut e = ble.init()
    if e != ble.err_ok() {
        return
    }
    e = ble.advertise("klin")
    if e != ble.err_ok() {
        return
    }
    e = ble.wait_connected(-1)
    if e != ble.err_ok() {
        return
    }
}
```

```sh
klin get github/klin-lang/gd32v_ble@v0.1.0
```

## Links

- Package: https://github.com/klin-lang/gd32v_ble  
- Tag: [v0.1.0](https://github.com/klin-lang/gd32v_ble/releases/tag/v0.1.0)  
- SDK: https://github.com/GigaDeviceSemiconductor/GD32VW55x_WiFi_BLE_SDK  
- AN152 BLE Development Guide (GigaDevice)  
- Chip MMIO: [117](117-machine-gd32v-gd32vw553.md) / [`machine_gd32v`](https://github.com/klin-lang/machine_gd32v)  
- Wi‑Fi sibling: [126](126-gd32v-wifi-sdk.md) / [`gd32v_wifi`](https://github.com/klin-lang/gd32v_wifi)  
- ESP BLE sibling (different engine): [106](106-esp-ble-idf.md)  
- Catalog: [061](061-micropython-machine-api.md), targets [062](062-targets-esp-rp.md)
