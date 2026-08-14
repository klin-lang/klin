# 130 — GD32VW553 BLE as a separate SDK package (`gd32v_ble`)

**Status:** 🔨 advertise + GATT published [`@v0.2.0`](https://github.com/klin-lang/gd32v_ble/releases/tag/v0.2.0) (central later)  
**Depends on:** [021](021-c-libraries.md), [024](024-rtos.md), [049](049-remote-imports.md), [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md), [117](117-machine-gd32v-gd32vw553.md), [126](126-gd32v-wifi-sdk.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | External: [`klin-lang/gd32v_ble`](https://github.com/klin-lang/gd32v_ble) `@v0.2.0` |
| Engine | **GigaDevice VW55x BLE SDK** (AN152 stack + `MSDK/ble/app` managers + `ble_gatts_*`) — not MMIO, **not** ESP-IDF NimBLE |
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
GATT uses the stack GATTS API (`ble_gatts_svc_add` / `ble_gatts_ntf_ind_send`
in `MSDK/blesw/src/export/ble_gatts.h`) — same pattern as SDK
`MSDK/ble/profile/dis/ble_diss.c` / `profile/sample/ble_sample_srv.c`.
`BLE_GAP_ADV_PROP_UNDIR_CONN` is GigaDevice `ble_gap.h`, not NimBLE.

## Scope (`@v0.1.0` — advertise)

- `init` — `ble_init(true)` + `ble_wait_ready` (once)  
- `advertise(name)` — `app_adp_set_name` + `app_adv_create` (wraps `ble_adv_create`) legacy undirected connectable (`BLE_GAP_ADV_PROP_UNDIR_CONN` in GigaDevice `ble_gap.h`)  
- `wait_connected(timeout_ms)` — host stub succeeds after `advertise`; on-device polls a flag (`-1` = forever)  
- `connected` / `advertising` — `i32` 1/0  
- `stop_advertise` / `stop` — `app_adv_stop` / `ble_deinit`  
- `err_ok` / `version()` → `1`  
- Implementation: `@[link("ble_sdk.c")]` + `@[cimport]` (no `@[cinclude]`)  
- Host tests use the C file **without** SDK headers (`__has_include` stubs)  
- Example `examples/advertise/` — needs the official SDK to link an ELF  

## Scope (`@v0.2.0` — GATT server MVP)

Same Klin names as [`esp_ble`](https://github.com/klin-lang/esp_ble) `@v0.2.0`:

- Fixed primary service **0xFFF0**, characteristic **0xFFF1** (read / write / notify)  
- `gatt_set` / `gatt_get` / `gatt_len` / `gatt_value_max()` — caller copies; max **20** bytes; `gatt_set` does **not** notify  
- `gatt_notify` — `ble_gatts_ntf_ind_send` if connected **and** CCCD notify enabled; else no-op  
- `gatt_written` — poll-and-clear (`bool`); no Klin callbacks  
- `gatt_svc_uuid16()` / `gatt_chr_uuid16()` — `0xFFF0` / `0xFFF1`  
- `init` also calls `ble_gatts_svc_add` (AN152 §3.3)  
- `wait_connected` on-device: flag set by GATTS `BLE_SRV_EVT_CONN_STATE_CHANGE_IND`  
- `version()` → `2`  
- Example `examples/gatt/`  

## Out of scope (this tag)

- GATT client / discover / `gattc_*`  
- Central scan + connect  
- Bonding / passkey / privacy / Mesh  
- Custom UUID16/128 (later, like [`esp_ble`](https://github.com/klin-lang/esp_ble) `@v0.6.0`)  
- Wi‑Fi — [`gd32v_wifi`](https://github.com/klin-lang/gd32v_wifi) [126](126-gd32v-wifi-sdk.md)  
- Board packs — [127](127-board-gd32vw553h-eval.md) / [129](129-board-gd32vw553h-start.md) (no radio API)  
- Vendoring `GD32VW55x_WiFi_BLE_SDK`  
- Using [`esp_ble`](https://github.com/klin-lang/esp_ble) on VW553  

## Contract (prime rule)

- No Klin GC / hidden heap — advertise name is a C string you pass in; GATT payloads are caller buffers + a fixed 20-byte static in C.  
- SDK heap / OSAL BLE task / GAP / GATTS events are **SDK contracts**, documented in the package README.  
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
    let mut seed: [1]u8
    seed[0] = 42
    e = ble.gatt_set(cast(*u8, &seed[0]), 1)
    if e != ble.err_ok() {
        return
    }
    e = ble.advertise("klin-gatt")
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
klin get github/klin-lang/gd32v_ble@v0.2.0
```

## Links

- Package: https://github.com/klin-lang/gd32v_ble  
- Tag: [v0.2.0](https://github.com/klin-lang/gd32v_ble/releases/tag/v0.2.0) (advertise [v0.1.0](https://github.com/klin-lang/gd32v_ble/releases/tag/v0.1.0))  
- SDK: https://github.com/GigaDeviceSemiconductor/GD32VW55x_WiFi_BLE_SDK  
- AN152 BLE Development Guide (GigaDevice)  
- Chip MMIO: [117](117-machine-gd32v-gd32vw553.md) / [`machine_gd32v`](https://github.com/klin-lang/machine_gd32v)  
- Wi‑Fi sibling: [126](126-gd32v-wifi-sdk.md) / [`gd32v_wifi`](https://github.com/klin-lang/gd32v_wifi)  
- ESP BLE sibling (different engine): [106](106-esp-ble-idf.md)  
- Catalog: [061](061-micropython-machine-api.md), targets [062](062-targets-esp-rp.md)
