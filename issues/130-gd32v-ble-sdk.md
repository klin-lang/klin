# 130 — GD32VW553 BLE as a separate SDK package (`gd32v_ble`)

**Status:** 🔨 advertise + GATT + central + GATT client + Just Works bonding published [`@v0.5.0`](https://github.com/klin-lang/gd32v_ble/releases/tag/v0.5.0) (passkey / custom UUID later)  
**Depends on:** [021](021-c-libraries.md), [024](024-rtos.md), [049](049-remote-imports.md), [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md), [117](117-machine-gd32v-gd32vw553.md), [126](126-gd32v-wifi-sdk.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | External: [`klin-lang/gd32v_ble`](https://github.com/klin-lang/gd32v_ble) `@v0.5.0` |
| Engine | **GigaDevice VW55x BLE SDK** (AN152 stack + `MSDK/ble/app` managers + `ble_gatts_*` / `ble_scan_*` / `ble_conn_*` / `ble_gattc_*` / `app_sec_*`) — not MMIO, **not** ESP-IDF NimBLE |
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
Scan / central use `ble_scan_*` / `ble_conn_*` (AN152).
GATT client uses `ble_gattc_*` (`ble_gattc_svc_reg` / `ble_gattc_start_discovery` /
`ble_gattc_read` / `ble_gattc_write_req` / find char+CCCD handles).
Bonding uses `app_sec_set_authen` / `app_sec_send_bond_req` + peer flash
(`ble_peer_all_addr_get` / `ble_peer_data_delete`); `ble_init` already calls
`app_sec_mgr_init`.
`BLE_GAP_ADV_PROP_UNDIR_CONN` is GigaDevice `ble_gap.h`, not NimBLE.

## Scope (`@v0.1.0` — advertise)

- `init` — `ble_init(true)` + `ble_wait_ready` (once)  
- `advertise(name)` — `app_adp_set_name` + `app_adv_create` (wraps `ble_adv_create`) legacy undirected connectable (`BLE_GAP_ADV_PROP_UNDIR_CONN` in GigaDevice `ble_gap.h`)  
- `wait_connected(timeout_ms)` — host stub succeeds after `advertise`; on-device polls a flag (`-1` = forever). GATTS connect hook arrives in `@v0.2.0` (this tag's `wait_connected` never saw a connect on-device)  
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
- `gatt_svc_uuid16()` / `gatt_chr_uuid16()` — fixed compile-time `0xFFF0` / `0xFFF1` (same helpers as `esp_ble@v0.2.0`; custom UUID later, like `esp_ble@v0.6.0`)  
- `init` also calls `ble_gatts_svc_add` (AN152 §3.3)  
- `wait_connected` on-device: flag set by GATTS `BLE_SRV_EVT_CONN_STATE_CHANGE_IND`  
- `version()` → `2`  
- Example `examples/gatt/`  

## Scope (`@v0.3.0` — central scan + connect)

Same Klin names as [`esp_ble`](https://github.com/klin-lang/esp_ble) `@v0.3.0`:

- `scan_max()` → **16** (fixed table; dedupe by address; **no** glue `malloc` — do not use SDK `app_scan_mgr`)  
- `scan_start(duration_ms)` — active scan (`ble_scan_param_set` / `ble_scan_enable`); stops advertising first; `duration_ms` must be `> 0`; blocks until duration elapses on-device  
- `scan_stop` / `scan_count` / `scan_rssi` / `scan_addr_type` / `scan_addr` / `scan_name`  
- `central_connect(index, timeout_ms)` — `ble_conn_connect` to scan row (GAP; then `gattc_discover` in `@v0.4.0`)  
- `central_wait_connected` / `central_connected()` (`bool`) / `central_disconnect`  
- `init` also registers scan + conn callbacks  
- `version()` → `3`  
- Example `examples/scan/`  
- **Board note:** needs an SDK image with **observer/central** roles (e.g. **msdk_ffd**). Default peripheral-only **msdk** may not export scan/central APIs.

## Scope (`@v0.4.0` — GATT client MVP)

Same Klin names as [`esp_ble`](https://github.com/klin-lang/esp_ble) `@v0.4.0`:

- After central connect: `gattc_discover(timeout_ms)` — `ble_gattc_start_discovery` for peer svc **0xFFF0** / chr **0xFFF1** (+ CCCD `0x2902` if present via `ble_gattc_find_desc_handle`)  
- `gattc_ready` / `gattc_read` / `gattc_write` / `gattc_subscribe`  
- `gattc_notified` (poll; clears) / `gattc_get` / `gattc_len` — same 20-byte max  
- `init` also calls `ble_gattc_svc_reg` for 0xFFF0  
- `version()` → `4`  
- Example `examples/gattc/` (pair with `examples/gatt/`)  
- **Board note:** needs **central + GATT client** in the SDK image (e.g. **msdk_ffd**)

## Scope (`@v0.5.0` — bonding Just Works)

Same Klin names as [`esp_ble`](https://github.com/klin-lang/esp_ble) `@v0.5.0`:

- `bond_enable` — SM config: no IO / no MITM / SC + bond (`app_sec_set_authen` + `app_sec_callbacks_set`)  
- `bond_start` — `app_sec_send_bond_req` on active link (central preferred, else peripheral)  
- `bonded` / `wait_bonded(timeout_ms)` — poll / block until pair success  
- `bond_count` / `bond_clear` — SDK peer flash (`ble_peer_all_addr_get` / `ble_peer_data_delete`)  
- Re-pair MVP: a new successful pair **replaces** the prior bond for that peer (same policy as `esp_ble@v0.5.0`)  
- `version()` → `5`  
- Example `examples/bond/`  
- **Not** included (until later, like `esp_ble@v0.7.0`): passkey / PIN MITM  

## Out of scope (this tag)

- Passkey / privacy / Mesh  
- Custom UUID16/128 (later, like [`esp_ble`](https://github.com/klin-lang/esp_ble) `@v0.6.0`)  
- Wi‑Fi — [`gd32v_wifi`](https://github.com/klin-lang/gd32v_wifi) [126](126-gd32v-wifi-sdk.md)  
- Board packs — [127](127-board-gd32vw553h-eval.md) / [129](129-board-gd32vw553h-start.md) (no radio API)  
- Vendoring `GD32VW55x_WiFi_BLE_SDK`  
- Using [`esp_ble`](https://github.com/klin-lang/esp_ble) on VW553  

## Contract (prime rule)

- No Klin GC / hidden heap — advertise name is a C string you pass in; GATT payloads are caller buffers + a fixed 20-byte static in C; scan results are a fixed 16-row static table; GATT client uses a fixed 20-byte client buffer; bond keys live in **SDK flash storage**.  
- SDK heap / OSAL BLE task / GAP / GATTS / GATTC / security / scan events are **SDK contracts**, documented in the package README.  
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
    e = ble.bond_enable()
    if e != ble.err_ok() {
        return
    }
    e = ble.advertise("klin-bond")
    if e != ble.err_ok() {
        return
    }
    e = ble.wait_connected(-1)
    if e != ble.err_ok() {
        return
    }
    e = ble.bond_start()
    if e != ble.err_ok() {
        return
    }
    e = ble.wait_bonded(60000)
    if e != ble.err_ok() {
        return
    }
}
```

```sh
klin get github/klin-lang/gd32v_ble@v0.5.0
```

## Links

- Package: https://github.com/klin-lang/gd32v_ble  
- Tag: [v0.5.0](https://github.com/klin-lang/gd32v_ble/releases/tag/v0.5.0) (GATT client [v0.4.0](https://github.com/klin-lang/gd32v_ble/releases/tag/v0.4.0), central [v0.3.0](https://github.com/klin-lang/gd32v_ble/releases/tag/v0.3.0), GATT [v0.2.0](https://github.com/klin-lang/gd32v_ble/releases/tag/v0.2.0), advertise [v0.1.0](https://github.com/klin-lang/gd32v_ble/releases/tag/v0.1.0))  
- SDK: https://github.com/GigaDeviceSemiconductor/GD32VW55x_WiFi_BLE_SDK  
- AN152 BLE Development Guide (GigaDevice)  
- Chip MMIO: [117](117-machine-gd32v-gd32vw553.md) / [`machine_gd32v`](https://github.com/klin-lang/machine_gd32v)  
- Wi‑Fi sibling: [126](126-gd32v-wifi-sdk.md) / [`gd32v_wifi`](https://github.com/klin-lang/gd32v_wifi)  
- ESP BLE sibling (different engine): [106](106-esp-ble-idf.md)  
- Catalog: [061](061-micropython-machine-api.md), targets [062](062-targets-esp-rp.md)
