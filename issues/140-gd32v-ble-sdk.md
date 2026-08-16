# 140 — GD32VW553 BLE as a separate SDK package (`gd32v_ble`)

**Status:** 🔨 advertise + GATT + central + GATT client + Just Works bonding + UUID16 + passkey + UUID128/multi + privacy + Mesh OnOff + Mesh provisioner + Gen Level/vendor + Friend/LPN + interactive OOB published [`@v0.14.0`](https://github.com/klin-lang/gd32v_ble/releases/tag/v0.14.0)  
**Depends on:** [021](021-c-libraries.md), [024](024-rtos.md), [049](049-remote-imports.md), [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md), [136](136-machine-gd32v-gd32vw553.md), [137](137-gd32v-wifi-sdk.md)
**Formerly:** `130` (renumbered to resolve duplicate issue numbers).

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | External: [`klin-lang/gd32v_ble`](https://github.com/klin-lang/gd32v_ble) `@v0.14.0` |
| Engine | **GigaDevice VW55x BLE SDK** (AN152 stack + `MSDK/ble/app` managers + `ble_gatts_*` / `ble_scan_*` / `ble_conn_*` / `ble_gattc_*` / `app_sec_*` / `ble_adp_privacy_recfg` / `bt_mesh_*` / CDB) — not MMIO, **not** ESP-IDF NimBLE |
| Relation to `machine_gd32v` | **Separate.** Pin…Adc twins stay MMIO ([136](136-machine-gd32v-gd32vw553.md)). Same split as [`esp_ble`](https://github.com/klin-lang/esp_ble) vs `machine_esp` ([106](106-esp-ble-idf.md)). |
| Relation to `gd32v_wifi` | Sibling radio package ([137](137-gd32v-wifi-sdk.md)). Not the same Klin module. |

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
Privacy uses `ble_adp_privacy_recfg` + `BLE_GAP_LOCAL_ADDR_RESOLVABLE` for
adv/scan/connect (controller RPA — not NimBLE `ble_hs_pvcy_rpa_config`).
Mesh uses Zephyr-style `bt_mesh_init` + Gen OnOff / Level / vendor (`mesh_cfg.h` /
BLE_MAX — same class as SDK `light_demo` / `vnd_module`; not NimBLE
`CONFIG_BT_NIMBLE_MESH`). Friend / LPN use `bt_mesh_lpn_*` /
`bt_mesh_friend_terminate` when `CONFIG_BT_MESH_LOW_POWER` /
`CONFIG_BT_MESH_FRIEND`.
Interactive OOB uses `bt_mesh_auth_method_set_*` / `bt_mesh_input_number`
(provisioner capabilities + non-blocking `mesh_prov_*_begin`).
Provisioner uses CDB (`bt_mesh_cdb_create` / `bt_mesh_provision_adv|gatt`) when
`CONFIG_BT_MESH_PROVISIONER` + `CONFIG_BT_MESH_CDB` (SDK `provisioner` example).
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
- `gatt_svc_uuid16()` / `gatt_chr_uuid16()` — fixed compile-time `0xFFF0` / `0xFFF1` until `@v0.6.0`  
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
- Passkey / PIN arrives in `@v0.7.0`  

## Scope (`@v0.6.0` — custom UUID16)

Same Klin names as [`esp_ble`](https://github.com/klin-lang/esp_ble) `@v0.6.0`:

- `gatt_uuid16(svc, chr)` — own **16-bit** service/characteristic (default remains **0xFFF0** / **0xFFF1**)  
- Must be called **before** `init` (after init → `-1`)  
- Affects peripheral GATT DB and `gattc_discover` (active UUID16)  
- `gatt_svc_uuid16()` / `gatt_chr_uuid16()` return the **active** values (not hardcoded Klin constants)  
- `version()` → `6`  
- Example `examples/uuid/`  
- UUID128 / multi-service arrives in `@v0.8.0`  

## Scope (`@v0.7.0` — passkey / PIN MITM)

Same Klin names as [`esp_ble`](https://github.com/klin-lang/esp_ble) `@v0.7.0`:

- `bond_passkey(pin)` — fixed 6-digit PIN (`0..=999999`); MITM + keyboard/display IO (`app_sec_set_authen` + `app_sec_pin_code_set`)  
- On input-key request the PIN is **auto-injected** (`app_sec_input_passkey`); numeric comparison **auto-accepted** (`app_sec_num_compare`)  
- `passkey()` / `passkey_action()` / `passkey_inject(pin)` helpers  
- Replaces Just Works SM config from `bond_enable` when used  
- `version()` → `7`  
- Example `examples/passkey/` (PIN `123456`)  
- **Not** included: interactive display UX beyond the fixed PIN; LE privacy  

## Scope (`@v0.8.0` — 128-bit UUID + multiple services)

Same Klin names as [`esp_ble`](https://github.com/klin-lang/esp_ble) `@v0.8.0`:

- Up to **4** services, **1** R/W/Notify characteristic each (`gatt_svc_max()` → `4`)  
- Before `init`: `gatt_clear` / `gatt_uuid16` / `gatt_uuid128` (slot 0) / `gatt_add_uuid16` / `gatt_add_uuid128`  
- 128-bit buffers are **16 bytes little-endian** (Bluetooth wire order)  
- Per-slot: `gatt_set_at` / `gatt_get_at` / `gatt_len_at` / `gatt_notify_at` / `gatt_written_at` (slot-0 wrappers keep prior API)  
- Client: `gattc_select(index)` or `gattc_uuid16` / `gattc_uuid128` override before `gattc_discover`  
- Default remains svc **0xFFF0** / chr **0xFFF1** when the table is empty at `init`  
- Engine: per-slot `ble_gatts_svc_add` (`SVC_UUID(16|128)` + `ATT_UUID(128)` for 128-bit chars)  
- **AD note:** advertise still uses GD32 `app_adv_create` name-only path (no AD service UUID list packed like NimBLE)  
- `version()` → `8`  
- Example `examples/multi/`  
- **Not** included (until later, like `esp_ble@v0.9.0`): LE privacy  

## Scope (`@v0.9.0` — LE privacy / controller RPA)

Same Klin names as [`esp_ble`](https://github.com/klin-lang/esp_ble) `@v0.9.0`:

- `privacy_enable` / `privacy_disable` — after `init`, **before** advertise / scan / connect (fail if radio busy)  
- Controller RPA via `ble_adp_privacy_recfg(PRIV_EN_BIT|0, NULL)`; adv/scan/connect use `BLE_GAP_LOCAL_ADDR_RESOLVABLE` when privacy is on  
- `privacy_enabled` / `own_addr_type` / `own_addr(*mut u8)` — query own address (`own_addr_type` is GD32 enum 0/1; `own_addr` uses `ble_adp_public_addr_get` / `ble_adp_identity_addr_get`, no RPA event cache)  
- Bonding already distributes IRK (`bond_enable` / `bond_passkey`) for peer resolution  
- `version()` → `9`  
- Example `examples/privacy/`  
- **Not** included (until `@v0.10.0`): Mesh — see below; host-RPA knobs beyond controller privacy  

## Scope (`@v0.10.0` — Mesh Gen OnOff)

Same Klin names as [`esp_ble`](https://github.com/klin-lang/esp_ble) `@v0.10.0`:

- `mesh_enable` — after `init`; composition: Config + Health + **Generic OnOff** server  
- Needs SDK **mesh** headers (`mesh_cfg.h` + `generic_server.h`) and a **BLE_MAX** link image (same class as SDK `light_demo`)  
- Without mesh headers → `mesh_enable` returns `-1` (not supported)  
- Unprovisioned: starts **PB-ADV + PB-GATT**; OOB display number via `mesh_oob_number`  
- `mesh_provisioned` / `mesh_primary_addr` / `mesh_onoff` / `mesh_onoff_set` / `mesh_onoff_changed` / `mesh_reset`  
- Not the same path as `advertise` — mesh owns provisioning bearers  
- Engine: Zephyr-style `bt_mesh_init` / `bt_mesh_prov_enable` (not NimBLE `CONFIG_BT_NIMBLE_MESH`)  
- `version()` → `10`  
- Example `examples/mesh/`  
- **Not** included (until `@v0.11.0` / `@v0.12.0` / `@v0.13.0`): provisioner — see below; Gen Level / vendor — see `@v0.12.0`; Friend/LPN — see `@v0.13.0`  

## Scope (`@v0.11.0` — Mesh provisioner)

- `mesh_provisioner_enable` — after `init`; creates CDB + self-provisions at addr **1** (fixed demo net/dev keys)  
- Mutually exclusive with `mesh_enable` (Gen OnOff node)  
- Needs `CONFIG_BT_MESH_PROVISIONER` + `CONFIG_BT_MESH_CDB` (+ BLE_MAX); otherwise returns `-1`  
- Unprov beacons fill a fixed table (`mesh_unprov_count` / `mesh_unprov_uuid` / `mesh_unprov_clear`; max **8**)  
- `mesh_prov_adv(index, addr, timeout_ms)` / `mesh_prov_gatt` — PB-ADV / PB-GATT; `addr` 0 = auto; blocks until `node_added`  
- Auth: auto `bt_mesh_auth_method_set_none` until `@v0.14.0` interactive OOB  
- `mesh_cdb_count` / `mesh_cdb_addr(index)` — dense view of allocated CDB nodes  
- `version()` → `11`  
- Example `examples/mesh_prov/`  
- **Not** included (until `@v0.12.0` / `@v0.13.0` / `@v0.14.0`): Gen Level / vendor — see below; Friend / LPN — see `@v0.13.0`; interactive OOB — see `@v0.14.0`  

## Scope (`@v0.12.0` — Mesh Gen Level + vendor)

On the **`mesh_enable` node** composition (not provisioner):

- Add **Generic Level** server: `mesh_level` / `mesh_level_set` / `mesh_level_changed` (int16, clamped)  
- Add **vendor button** model (company `0x05F1`, model `0x0000`): `mesh_vnd` / `mesh_vnd_set` / `mesh_vnd_changed` (0 = released, 1 = pressed)  
- Vendor opcodes: pressed / released (`BT_MESH_MODEL_OP_3`) — same shape as SDK `vnd_module`  
- Engine: `BT_MESH_MODEL_GEN_LEVEL_SRV` + `BT_MESH_MODEL_VND_CB`  
- `version()` → `12`  
- Example `examples/mesh_level/`  
- **Not** included (until `@v0.13.0` / `@v0.14.0`): Friend / LPN knobs — see below; interactive OOB — see `@v0.14.0`; extra vendor models still later  

## Scope (`@v0.13.0` — Mesh Friend / LPN)

On the **`mesh_enable` node** (not provisioner):

- `mesh_lpn_supported` / `mesh_friend_supported` — compile-time probes (`CONFIG_BT_MESH_LOW_POWER` / `CONFIG_BT_MESH_FRIEND`)  
- LPN: `mesh_lpn_set` / `mesh_lpn` / `mesh_lpn_poll` / `mesh_lpn_established` / `mesh_lpn_friend_addr` / `mesh_lpn_changed`  
- Friend: `mesh_friend_established` / `mesh_friend_lpn_addr` / `mesh_friend_terminate` / `mesh_friend_changed`  
- Engine: `bt_mesh_lpn_set` / `bt_mesh_lpn_poll` / `bt_mesh_friend_terminate` + friendship callbacks  
- Without the matching CONFIG → `supported` is false / calls return `-1`  
- `version()` → `13`  
- Example `examples/mesh_friend/`  
- **Not** included (until `@v0.14.0`): interactive OOB — see below; extra vendor models; Friend queue tuning knobs beyond SDK defaults  

## Scope (`@v0.14.0` — Mesh interactive OOB)

- `mesh_oob_auth_set(mode)` / `mesh_oob_auth` — provisioner auth: **0** none (default), **1** output (`DISPLAY_NUMBER`), **2** input (`ENTER_NUMBER`), **3** static  
- `mesh_oob_static_set(data, len)` — static OOB bytes (**1..=16**); before `mesh_enable` (node) or `auth_set(3)`  
- `mesh_oob_action` — **0** idle / **1** display `mesh_oob_number` / **2** enter via `mesh_oob_input_number`  
- `mesh_oob_input_number` / `mesh_oob_changed` — inject (`bt_mesh_input_number`) + poll-and-clear  
- Node composition advertises **DISPLAY_NUMBER** + **ENTER_NUMBER** (plus optional static)  
- Non-blocking provision: `mesh_prov_adv_begin` / `mesh_prov_gatt_begin` / `mesh_prov_busy` (needed for interactive OOB; blocking `mesh_prov_adv`/`gatt` remain for none/static)  
- Engine: `bt_mesh_auth_method_set_{none,output,input,static}` in provisioner `capabilities`  
- `version()` → `14`  
- Example `examples/mesh_oob/`  
- **Not** included (until later): Friend queue tuning beyond SDK defaults; extra vendor models; string OOB  

## Out of scope (this tag)

- Friend queue tuning beyond SDK defaults / string OOB / extra vendor models  
- Wi‑Fi — [`gd32v_wifi`](https://github.com/klin-lang/gd32v_wifi) [137](137-gd32v-wifi-sdk.md)  
- Board packs — [138](138-board-gd32vw553h-eval.md) / [139](139-board-gd32vw553h-start.md) (no radio API)  
- Vendoring `GD32VW55x_WiFi_BLE_SDK`  
- Using [`esp_ble`](https://github.com/klin-lang/esp_ble) on VW553  

## Contract (prime rule)

- No Klin GC / hidden heap — advertise name is a C string you pass in; GATT payloads are caller buffers + fixed per-slot 20-byte statics in C (max 4 slots); scan results are a fixed 16-row static table; GATT client uses a fixed 20-byte client buffer; bond keys live in **SDK flash storage**; passkey is an explicit `i32` PIN; 128-bit UUIDs are explicit 16-byte LE buffers. UUID table frozen at `init`. Unprov UUID table max 8. Static OOB is a fixed 16-byte buffer.  
- `privacy_enable` only when radio is idle (not advertising / scanning / connected).  
- Mesh needs explicit SDK mesh + BLE_MAX; provisioner needs PROVISIONER+CDB; Friend/LPN need LOW_POWER / FRIEND; mesh stack buffers are **SDK contracts**.  
- Interactive OOB: no Klin callbacks — poll `mesh_oob_action` / `mesh_prov_busy` after `mesh_prov_*_begin`.  
- `mesh_enable` and `mesh_provisioner_enable` are mutually exclusive.  
- SDK heap / OSAL BLE task / GAP / GATTS / GATTC / security / privacy / mesh / scan events are **SDK contracts**, documented in the package README.  
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
    e = ble.mesh_provisioner_enable()
    if e != ble.err_ok() {
        return
    }
    e = ble.mesh_oob_auth_set(1)
    e = ble.mesh_prov_adv_begin(0, 2)
    while ble.mesh_prov_busy() {
        if ble.mesh_oob_action() == 2 {
            e = ble.mesh_oob_input_number(ble.mesh_oob_number())
        }
    }
}
```

```sh
klin get github/klin-lang/gd32v_ble@v0.14.0
```

## Links

- Package: https://github.com/klin-lang/gd32v_ble  
- Tag: [v0.14.0](https://github.com/klin-lang/gd32v_ble/releases/tag/v0.14.0) (Friend/LPN [v0.13.0](https://github.com/klin-lang/gd32v_ble/releases/tag/v0.13.0), Level/vendor [v0.12.0](https://github.com/klin-lang/gd32v_ble/releases/tag/v0.12.0), provisioner [v0.11.0](https://github.com/klin-lang/gd32v_ble/releases/tag/v0.11.0), Mesh OnOff [v0.10.0](https://github.com/klin-lang/gd32v_ble/releases/tag/v0.10.0), privacy [v0.9.0](https://github.com/klin-lang/gd32v_ble/releases/tag/v0.9.0), UUID128/multi [v0.8.0](https://github.com/klin-lang/gd32v_ble/releases/tag/v0.8.0), passkey [v0.7.0](https://github.com/klin-lang/gd32v_ble/releases/tag/v0.7.0), UUID16 [v0.6.0](https://github.com/klin-lang/gd32v_ble/releases/tag/v0.6.0), bonding [v0.5.0](https://github.com/klin-lang/gd32v_ble/releases/tag/v0.5.0), GATT client [v0.4.0](https://github.com/klin-lang/gd32v_ble/releases/tag/v0.4.0), central [v0.3.0](https://github.com/klin-lang/gd32v_ble/releases/tag/v0.3.0), GATT [v0.2.0](https://github.com/klin-lang/gd32v_ble/releases/tag/v0.2.0), advertise [v0.1.0](https://github.com/klin-lang/gd32v_ble/releases/tag/v0.1.0))  
- SDK: https://github.com/GigaDeviceSemiconductor/GD32VW55x_WiFi_BLE_SDK  
- AN152 BLE Development Guide (GigaDevice)  
- Chip MMIO: [136](136-machine-gd32v-gd32vw553.md) / [`machine_gd32v`](https://github.com/klin-lang/machine_gd32v)  
- Wi‑Fi sibling: [137](137-gd32v-wifi-sdk.md) / [`gd32v_wifi`](https://github.com/klin-lang/gd32v_wifi)  
- ESP BLE sibling (different engine): [106](106-esp-ble-idf.md)  
- Catalog: [061](061-micropython-machine-api.md), targets [062](062-targets-esp-rp.md)
