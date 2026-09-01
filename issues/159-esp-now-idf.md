# 159 — ESP-NOW as a separate IDF package (`espnow`)

**Status:** ✅ published [`espnow@v0.1.0`](https://github.com/klin-lang/espnow/releases/tag/v0.1.0)
(mirror [`patches/espnow-v0.1.0/`](../patches/espnow-v0.1.0/))  
**Depends on:** [021](021-c-libraries.md), [024](024-rtos.md), [049](049-remote-imports.md),
[061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md), [101](101-esp-wifi-idf.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | External: [`klin-lang/espnow`](https://github.com/klin-lang/espnow) `@v0.1.0` |
| Package / module name | **`espnow`** (no underscore) — Klin C symbols must not collide with IDF `esp_now_*` |
| Engine | **ESP-IDF** v5.x (`esp_wifi` STA + `esp_now_*` / NVS / event loop) — not MMIO |
| Relation to `machine_esp` | **Separate.** Same class as [`esp_wifi`](https://github.com/klin-lang/esp_wifi) / [`esp_ble`](https://github.com/klin-lang/esp_ble): IDF radio stack, not `machine_*`. |
| Cross-MCU? | **No.** ESP-NOW is Espressif-only (ESP32 / S* / C* with Wi‑Fi). |

## Why not `machine_esp.EspNow` / fold into `esp_wifi`?

[`machine_esp`](https://github.com/klin-lang/machine_esp) is approach **C** — thin Klin over **explicit MMIO**. ESP-NOW needs the IDF Wi‑Fi + ESP-NOW stack (NVS, event loop, firmware blobs). Folding that into `machine_*` would hide IDF cost and break the MMIO contract.

[`esp_wifi`](https://github.com/klin-lang/esp_wifi) is STA/SoftAP/scan/IP. ESP-NOW is connectionless peer frames **without** the IP path. A sibling package keeps both surfaces small and avoids pulling ESP-NOW into every STA app.

## Scope (`@v0.1.0`)

- `init` — NVS + netif + default event loop + Wi‑Fi STA (no AP association) + `esp_wifi_start` + default channel **1** + `esp_now_init` + send/recv callbacks  
- `deinit` / `stop` — `esp_now_deinit` + `esp_wifi_stop`; clears peers + RX ring  
- `set_channel(1..13)` / `channel` — both peers must match  
- `mac_self(out6)` — STA MAC into caller 6-byte buffer  
- `add_peer(mac6, channel)` / `del_peer` / `peer_exists` — **unencrypted**; `channel` 0 = current  
- `add_broadcast` — peer `ff:ff:ff:ff:ff:ff` (required before broadcast send)  
- `send` / `send_wait` / `send_ok` / `send_done` — poll send CB (no Klin callbacks)  
- `recv_count` / `recv_available` / `recv` — fixed RX ring (**8** × **250**); overflow drops **newest**  
- `data_max()` → **250**; `recv_queue_max()` → **8**  
- `log_self` — debug `printf`  
- Implementation: `@[link("now_idf.c")]` + `@[cimport]`  
- Smoke: `examples/smoke/` (`--emit-c`, no IDF)  
- Hardware: `examples/peer_s3/` (ESP32-S3, `idf.py`)  

### Later (not this tag)

- PMK / LMK encryption (`esp_now_set_pmk` + per-peer LMK)  
- ESP-NOW v2 longer frames (`ESP_NOW_MAX_DATA_LEN_V2`)  
- SoftAP interface for ESP-NOW / coexistence knobs beyond IDF defaults  
- Rate config / power-save window helpers  

## Out of scope

- Freestanding (no IDF)  
- Non-Espressif MCUs (protocol is vendor-specific)  
- Folding into `esp_wifi` or `machine_esp`  
- Changing the Klin compiler  

## Contract (prime rule)

- No Klin GC / hidden heap — MAC and payloads are **caller** buffers.  
- RX ring depth **8**; overflow drops the newest frame (documented).  
- Max payload **250** bytes on this tag.  
- Peers are unencrypted; encryption is an explicit later tag.  
- Send/recv use **poll** APIs — no Klin callbacks from the Wi‑Fi task.  
- IDF Wi‑Fi / ESP-NOW heap and tasks are **IDF contracts**.  
- Errors are `i32` (`esp_err_t`); 0 = OK.  

## Usage

```sh
klin get github/klin-lang/espnow@v0.1.0
```

```klin
import "github/klin-lang/espnow" now

@[cexport, codename("klin_app_main")]
fn app() {
  let mut e = now.init()
  if e != now.err_ok() {
    return
  }
  e = now.set_channel(6)
  if e != now.err_ok() {
    return
  }
  e = now.add_broadcast()
  if e != now.err_ok() {
    return
  }
  now.log_self()
}
```

## Links

- Pack: https://github.com/klin-lang/espnow  
- Tag: [v0.1.0](https://github.com/klin-lang/espnow/releases/tag/v0.1.0)  
- Mirror: [`patches/espnow-v0.1.0/`](../patches/espnow-v0.1.0/)  
- Wi‑Fi sibling: [101](101-esp-wifi-idf.md) / https://github.com/klin-lang/esp_wifi  
- BLE sibling: [106](106-esp-ble-idf.md) / https://github.com/klin-lang/esp_ble  
- Network later: [104](104-later-tracks-esp-network.md)  
- Targets: [062](062-targets-esp-rp.md)  
- Board RLCD-4.2 (uses separately): [163](163-board-waveshare-esp32-s3-rlcd-42.md)  
