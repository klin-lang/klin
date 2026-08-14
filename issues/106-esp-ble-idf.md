# 106 — ESP BLE as a separate IDF package (`esp_ble`)

**Status:** ✅ published `@v0.9.0` (GATT + scan/client + bond + UUID16/128 + multi-svc + passkey + privacy/RPA)  
**Depends on:** [021](021-c-libraries.md), [024](024-rtos.md), [049](049-remote-imports.md), [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md), [101](101-esp-wifi-idf.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | External: [`klin-lang/esp_ble`](https://github.com/klin-lang/esp_ble) `@v0.9.0` |
| Engine | **ESP-IDF** v5.x **NimBLE** (`nimble_port` / GAP / GATTS / GATTC / SM store) — not MMIO |
| Relation to `machine_esp` | **Separate.** Same class as [`esp_wifi`](https://github.com/klin-lang/esp_wifi) ([101](101-esp-wifi-idf.md)) / [`esp_eth`](https://github.com/klin-lang/esp_eth) ([102](102-esp-eth-idf.md)): IDF radio stack, not `machine_*`. |
| µPython analogy | Outside `machine` — closer to `bluetooth` / BLE peripheral APIs ([061](061-micropython-machine-api.md)). |

## Why not `machine_esp.Ble`?

[`machine_esp`](https://github.com/klin-lang/machine_esp) is approach **C** — thin Klin over **explicit MMIO**. BLE needs the IDF NimBLE host (controller, FreeRTOS host task, GAP/GATT). Folding that into `machine_*` would hide IDF cost and break the MMIO contract. Pattern matches [`esp_wifi`](https://github.com/klin-lang/esp_wifi) / [`klin_freertos`](https://github.com/klin-lang/klin_freertos): C engine + Klin FFI client ([024](024-rtos.md)).

Board pack [100](100-board-waveshare-esp32-s3-pico.md) stays pins/WS2812/buses — **no** BLE API there either.

## Scope

### `@v0.1.0` — advertise (peripheral)

- `init` — NVS + NimBLE FreeRTOS host task (+ GATT registration from `@v0.2.0` onward)  
- `advertise(name)` / `wait_connected` / `connected` / `advertising` / `stop_advertise` / `stop`  
- After peripheral disconnect, C glue **restarts advertising** when that path was used  

### `@v0.2.0` — GATT server MVP

- Fixed primary service **0xFFF0**, characteristic **0xFFF1** (read / write / notify)  
- `gatt_set` / `gatt_get` / `gatt_len` / `gatt_value_max()` — caller copies; max **20** bytes  
- `gatt_notify` / `gatt_written` (poll; no Klin callbacks)  
- Example: `examples/gatt_s3/`

### `@v0.3.0` — central scan + connect

- `scan_start(duration_ms)` — blocking **active** scan; stops advertising first  
- Fixed result table: max **16** (deduped by address); `scan_max()`  
- `scan_count` / `scan_rssi` / `scan_addr_type` / `scan_addr(*mut u8)` / `scan_name`  
- `central_connect(index)` / `central_wait_connected` / `central_connected` / `central_disconnect`  
- Example: `examples/scan_s3/`  
- Requires NimBLE **central** + **observer** roles in sdkconfig  

### `@v0.4.0` — GATT client MVP

- After central connect: `gattc_discover` (blocking) for peer svc **0xFFF0** / chr **0xFFF1** (+ CCCD `0x2902` if present)  
- `gattc_ready` / `gattc_read` / `gattc_write` / `gattc_subscribe`  
- `gattc_notified` (poll; clears) / `gattc_get` / `gattc_len` — same 20-byte max  
- Example: `examples/gattc_s3/` (pair with `gatt_s3`)  

### `@v0.5.0` — bonding (Just Works)

- `bond_enable` — SM config (no IO / no MITM / SC + bonding key dist)  
- `bond_start` — `ble_gap_security_initiate` on active link (central preferred)  
- `wait_bonded` / `bonded` — after `ENC_CHANGE`  
- `bond_count` / `bond_clear` — NVS via NimBLE `ble_store`  
- Repeat-pairing replaces the old bond (explicit MVP policy)  
- Example: `examples/bond_s3/`  
- **Not** included (until `@v0.7.0`): passkey UI — see below; privacy RPA still later  

### `@v0.6.0` — custom UUID16

- `gatt_uuid16(svc, chr)` — own 16-bit service/characteristic (default remains **0xFFF0** / **0xFFF1**)  
- Must be called **before** `init` (after init → invalid state)  
- Affects peripheral GATT DB, advertising UUID list, and `gattc_discover`  
- `gatt_svc_uuid16()` / `gatt_chr_uuid16()` return the active values  
- Example: `examples/uuid_s3/`  

### `@v0.7.0` — passkey / PIN (MITM)

- `bond_passkey(pin)` — fixed 6-digit PIN (`0..=999999`); MITM + keyboard/display IO  
- On `PASSKEY_ACTION`, PIN is **auto-injected** (DISP/INPUT); NUMCMP accepted  
- `passkey()` / `passkey_action()` / `passkey_inject(pin)` helpers  
- Replaces Just Works SM config from `bond_enable` when used  
- Example: `examples/passkey_s3/` (PIN `123456`)  
- **Not** included: interactive display UX beyond the fixed PIN, LE privacy  

### `@v0.8.0` — 128-bit UUID + multiple services

- Up to **4** services, **1** R/W/Notify characteristic each (`gatt_svc_max()` → `4`)  
- Before `init`: `gatt_clear` / `gatt_uuid16` / `gatt_uuid128` (slot 0) / `gatt_add_uuid16` / `gatt_add_uuid128`  
- 128-bit buffers are **16 bytes little-endian** (Bluetooth wire order)  
- Per-slot: `gatt_set_at` / `gatt_get_at` / `gatt_len_at` / `gatt_notify_at` / `gatt_written_at` (slot-0 wrappers keep prior API)  
- Client: `gattc_select(index)` or `gattc_uuid16` / `gattc_uuid128` override before `gattc_discover`  
- Advertising includes all UUID16 service UUIDs when present; else first UUID128  
- Default remains svc **0xFFF0** / chr **0xFFF1** when the table is empty at `init`  
- Example: `examples/multi_s3/`  
- **Not** included (until `@v0.9.0`): LE privacy — see below; mesh still later  

### `@v0.9.0` — LE privacy / host RPA

- `privacy_enable` / `privacy_disable` — after `init`, **before** advertise / scan / connect  
- Host-based RPA via NimBLE `ble_hs_pvcy_rpa_config`; own address type → random  
- RPA rotation interval = IDF `CONFIG_BT_NIMBLE_RPA_TIMEOUT` (example: 900 s)  
- `privacy_enabled` / `own_addr_type` / `own_addr(*mut u8)` — query own address  
- Bonding already distributes IRK (`bond_enable` / `bond_passkey`) for peer resolution  
- Example: `examples/privacy_s3/`  
- **Not** included: controller-only privacy knobs beyond host RPA, mesh  

Implementation: `@[link("nimble_idf.c")]` + `@[cimport, cheader]`. Smoke: `examples/smoke/`.

## Out of scope

- BLE mesh  
- Coexistence policy beyond IDF defaults (Wi‑Fi + BLE together)  
- Freestanding (no IDF)  
- USB OTG / camera / Pico LCD shields — still [103](103-later-tracks-ble-usb-camera-lcd.md)

## Contract (prime rule)

- No Klin GC / hidden heap — names and payloads are buffers you pass in.  
- Scan overflow drops new addresses (fixed table).  
- UUID table is frozen at `init`; `gatt_*` / `gatt_add_*` before `init` only.  
- 128-bit UUIDs are explicit 16-byte LE buffers (no hidden allocation).  
- `privacy_enable` only when radio is idle (not advertising / scanning / connected).  
- Passkey is an explicit `i32` PIN; bonding keys are **IDF NVS / ble_store**.  
- NimBLE host task / controller buffers are **IDF contracts**.  
- Errors are `i32` (0 = OK).

## Usage (privacy / RPA)

```klin
import "github/klin-lang/esp_ble" ble

@[cexport, codename("klin_app_main")]
fn app() {
  let mut e = ble.init()
  if e != ble.err_ok() {
    return
  }
  e = ble.privacy_enable()
  if e != ble.err_ok() {
    return
  }
  e = ble.advertise("klin-rpa")
}
```

```sh
klin get github/klin-lang/esp_ble@v0.9.0
```

## Links

- Repo: https://github.com/klin-lang/esp_ble  
- Tag: [v0.9.0](https://github.com/klin-lang/esp_ble/releases/tag/v0.9.0)  
- Wi‑Fi sibling: [101](101-esp-wifi-idf.md) / [`esp_wifi`](https://github.com/klin-lang/esp_wifi)  
- Ethernet sibling: [102](102-esp-eth-idf.md) / [`esp_eth`](https://github.com/klin-lang/esp_eth)  
- Remaining later tracks: [103](103-later-tracks-ble-usb-camera-lcd.md)  
- Chip MMIO: [099](099-machine-esp-esp32-s3.md) / [`machine_esp`](https://github.com/klin-lang/machine_esp)  
- Board (no radio API): [100](100-board-waveshare-esp32-s3-pico.md)  
- Catalog: [061](061-micropython-machine-api.md), targets [062](062-targets-esp-rp.md)  
- RTOS FFI pattern: [024](024-rtos.md) / [028](028-freertos.md)
