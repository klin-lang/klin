# 106 — ESP BLE as a separate IDF package (`esp_ble`)

**Status:** ✅ published `@v0.1.0` (NimBLE peripheral advertise)  
**Depends on:** [021](021-c-libraries.md), [024](024-rtos.md), [049](049-remote-imports.md), [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md), [101](101-esp-wifi-idf.md), [103](103-later-tracks-ble-usb-camera-lcd.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | External: [`klin-lang/esp_ble`](https://github.com/klin-lang/esp_ble) `@v0.1.0` |
| Engine | **ESP-IDF** v5.x **NimBLE** (`nimble_port` / GAP advertise) — not MMIO |
| Relation to `machine_esp` | **Separate.** Same class as [`esp_wifi`](https://github.com/klin-lang/esp_wifi) ([101](101-esp-wifi-idf.md)) / [`esp_eth`](https://github.com/klin-lang/esp_eth) ([102](102-esp-eth-idf.md)): IDF radio stack, not `machine_*`. |
| µPython analogy | Outside `machine` — closer to `bluetooth` / BLE peripheral APIs ([061](061-micropython-machine-api.md)). |

## Why not `machine_esp.Ble`?

[`machine_esp`](https://github.com/klin-lang/machine_esp) is approach **C** — thin Klin over **explicit MMIO**. BLE needs the IDF NimBLE host (controller, FreeRTOS host task, GAP). Folding that into `machine_*` would hide IDF cost and break the MMIO contract. Pattern matches [`esp_wifi`](https://github.com/klin-lang/esp_wifi) / [`klin_freertos`](https://github.com/klin-lang/klin_freertos): C engine + Klin FFI client ([024](024-rtos.md)).

Board pack [100](100-board-waveshare-esp32-s3-pico.md) stays pins/WS2812/buses — **no** BLE API there either.

## Scope (`@v0.1.0`)

- `init` — NVS + `nimble_port_init` + NimBLE FreeRTOS host task  
- `advertise(name)` — undirected connectable GAP advertise (name copied in C)  
- `wait_connected(timeout_ms)` / `connected` / `advertising`  
- `stop_advertise` / `stop`  
- After disconnect, C glue **restarts advertising** (documented)  
- Implementation: `@[link("nimble_idf.c")]` + `@[cimport]` (no NimBLE header parser)  
- Examples: `examples/advertise_s3/` (ESP32-S3, `idf.py`); `examples/smoke/` (emit-c stubs)

## Out of scope

- GATT server / custom services / characteristics  
- Central / scanner role  
- Bonding / pairing / privacy  
- BLE mesh  
- Coexistence policy beyond IDF defaults (Wi‑Fi + BLE together)  
- Freestanding (no IDF)  
- USB OTG / camera / Pico LCD shields — still [103](103-later-tracks-ble-usb-camera-lcd.md)

## Contract (prime rule)

- No Klin GC / hidden heap — device name is a C string you pass in.  
- NimBLE host task / controller buffers are **IDF contracts**, documented in the package README.  
- Errors are `i32` (0 = OK).

## Usage

```klin
import "github/klin-lang/esp_ble" ble

@[cexport, codename("klin_app_main")]
fn app() {
  let mut e = ble.init()
  if e != ble.err_ok() {
    return
  }
  e = ble.advertise("klin-ble")
  if e != ble.err_ok() {
    return
  }
  e = ble.wait_connected(60000)
  if e != ble.err_ok() {
    return
  }
}
```

```sh
klin get github/klin-lang/esp_ble@v0.1.0
```

## Links

- Repo: https://github.com/klin-lang/esp_ble  
- Tag: [v0.1.0](https://github.com/klin-lang/esp_ble/releases/tag/v0.1.0)  
- Wi‑Fi sibling: [101](101-esp-wifi-idf.md) / [`esp_wifi`](https://github.com/klin-lang/esp_wifi)  
- Ethernet sibling: [102](102-esp-eth-idf.md) / [`esp_eth`](https://github.com/klin-lang/esp_eth)  
- Remaining later tracks: [103](103-later-tracks-ble-usb-camera-lcd.md)  
- Chip MMIO: [099](099-machine-esp-esp32-s3.md) / [`machine_esp`](https://github.com/klin-lang/machine_esp)  
- Board (no radio API): [100](100-board-waveshare-esp32-s3-pico.md)  
- Catalog: [061](061-micropython-machine-api.md), targets [062](062-targets-esp-rp.md)  
- RTOS FFI pattern: [024](024-rtos.md) / [028](028-freertos.md)
