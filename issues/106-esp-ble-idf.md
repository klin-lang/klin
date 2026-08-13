# 106 — ESP BLE as a separate IDF package (`esp_ble`)

**Status:** ✅ published `@v0.4.0` (advertise + GATT server + central scan/connect + GATT client)  
**Depends on:** [021](021-c-libraries.md), [024](024-rtos.md), [049](049-remote-imports.md), [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md), [101](101-esp-wifi-idf.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | External: [`klin-lang/esp_ble`](https://github.com/klin-lang/esp_ble) `@v0.4.0` |
| Engine | **ESP-IDF** v5.x **NimBLE** (`nimble_port` / GAP / GATTS / GATTC) — not MMIO |
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

Implementation: `@[link("nimble_idf.c")]` + `@[cimport]`. Smoke: `examples/smoke/`.

## Out of scope

- Custom / multiple services or 128-bit UUID tables  
- Bonding / pairing / privacy  
- BLE mesh  
- Coexistence policy beyond IDF defaults (Wi‑Fi + BLE together)  
- Freestanding (no IDF)  
- USB OTG / camera / Pico LCD shields — still [103](103-later-tracks-ble-usb-camera-lcd.md)

## Contract (prime rule)

- No Klin GC / hidden heap — names and payloads are buffers you pass in.  
- Scan overflow drops new addresses (fixed table).  
- Client discover targets the same fixed UUIDs as the server MVP.  
- NimBLE host task / controller buffers are **IDF contracts**.  
- Errors are `i32` (0 = OK).

## Usage (central + GATT client)

```klin
import "github/klin-lang/esp_ble" ble

@[cexport, codename("klin_app_main")]
fn app() {
  let mut e = ble.init()
  if e != ble.err_ok() {
    return
  }
  e = ble.scan_start(5000)
  if e != ble.err_ok() {
    return
  }
  if ble.scan_count() < 1 {
    return
  }
  e = ble.central_connect(0, 10000)
  if e != ble.err_ok() {
    return
  }
  e = ble.central_wait_connected(15000)
  if e != ble.err_ok() {
    return
  }
  e = ble.gattc_discover(10000)
  if e != ble.err_ok() {
    return
  }
  e = ble.gattc_subscribe(5000)
  e = ble.gattc_read(5000)
}
```

```sh
klin get github/klin-lang/esp_ble@v0.4.0
```

## Links

- Repo: https://github.com/klin-lang/esp_ble  
- Tag: [v0.4.0](https://github.com/klin-lang/esp_ble/releases/tag/v0.4.0)  
- Wi‑Fi sibling: [101](101-esp-wifi-idf.md) / [`esp_wifi`](https://github.com/klin-lang/esp_wifi)  
- Ethernet sibling: [102](102-esp-eth-idf.md) / [`esp_eth`](https://github.com/klin-lang/esp_eth)  
- Remaining later tracks: [103](103-later-tracks-ble-usb-camera-lcd.md)  
- Chip MMIO: [099](099-machine-esp-esp32-s3.md) / [`machine_esp`](https://github.com/klin-lang/machine_esp)  
- Board (no radio API): [100](100-board-waveshare-esp32-s3-pico.md)  
- Catalog: [061](061-micropython-machine-api.md), targets [062](062-targets-esp-rp.md)  
- RTOS FFI pattern: [024](024-rtos.md) / [028](028-freertos.md)
