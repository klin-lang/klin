# 101 — ESP Wi‑Fi as a separate IDF package (`esp_wifi`)

**Status:** ✅ published `@v0.4.0` (STA + SoftAP + scan + link stats + static IP / assoc)  
**Depends on:** [021](021-c-libraries.md), [024](024-rtos.md), [049](049-remote-imports.md), [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md), [099](099-machine-esp-esp32-s3.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | External: [`klin-lang/esp_wifi`](https://github.com/klin-lang/esp_wifi) `@v0.4.0` |
| Engine | **ESP-IDF** v5.x (`esp_wifi` / netif / event loop / NVS) — not MMIO |
| Relation to `machine_esp` | **Separate.** Radio is in silicon; `machine_*` MVP stays Pin…Adc(+Rmt). Same split as µPython `machine` vs `network` ([061](061-micropython-machine-api.md)). |

## Why not `machine_esp.Wifi`?

[`machine_esp`](https://github.com/klin-lang/machine_esp) is approach **C** — thin Klin over **explicit MMIO**. Wi‑Fi needs the IDF stack (NVS, netif, event loop, firmware blobs). Folding that into `machine_*` would hide IDF cost and break the MMIO contract. Pattern matches [`klin_freertos`](https://github.com/klin-lang/klin_freertos): C engine + Klin FFI client ([024](024-rtos.md)).

Board pack [100](100-board-waveshare-esp32-s3-pico.md) stays pins/WS2812/buses — **no** radio API there either.

## IP mode (dynamic vs static)

| Mode | Behavior |
|---|---|
| **DHCP (dynamic)** | **Default** — no extra call; `sta_wait_ip` waits for GOT_IP |
| **Static** | Opt-in via `sta_set_static_ip` (+ optional `sta_set_hostname`) — disables DHCP on the STA netif only |
| **SoftAP** | Default IDF AP IP (typically `192.168.4.1` + DHCPS); optional `ap_set_ip` |
| **Wi‑Fi + ETH together / APSTA** | Dual default-route glue ✅ [`esp_netif_dual`](https://github.com/klin-lang/esp_netif_dual) [113](113-esp-netif-dual-idf.md) ([104](104-later-tracks-esp-network.md) N1); **APSTA** still later; **do not** mix `sta_*` + `ap_*` in one binary on `@v0.4.0` |

Same idea as [`esp_eth`](https://github.com/klin-lang/esp_eth) ([102](102-esp-eth-idf.md)).

## Scope (`@v0.4.0`)

### STA (`@v0.1.0` / `@v0.1.1`)

- `sta_init` — NVS + netif + default event loop + `esp_wifi_init` + STA mode  
- `sta_set_static_ip` / `ipv4` / `sta_set_hostname` — optional; prefer before `sta_connect`  
- `sta_connect(ssid, pass)` — fill `wifi_config_t`, start, connect  
- `sta_wait_connected` / `sta_connected` — assoc (`WIFI_EVENT_STA_CONNECTED`)  
- `sta_wait_ip(timeout_ms)` — GOT_IP (`-1` = forever); DHCP or static  
- `sta_ip_u32` / `sta_gateway_u32` / `sta_netmask_u32` / `sta_log_ip` / `sta_log_ip_info`  
- `sta_disconnect` / `sta_stop`  
- Implementation: `@[link("sta_idf.c")]` + `@[cimport]` (no IDF header parser)  
- Example: `examples/sta_connect/` (ESP32-S3, `idf.py`)  

### SoftAP (`@v0.2.0` — [104](104-later-tracks-esp-network.md) W1)

- `ap_init` — NVS + netif + event loop + SoftAP mode (`WIFI_MODE_AP`)  
- `ap_set_ip` — optional AP IPv4 + DHCPS restart  
- `ap_start(ssid, pass, channel)` — channel `1`…`13`; empty pass = open; else WPA2 (≥8); max 4 STAs  
- `ap_wait_started` / `ap_started` — `WIFI_EVENT_AP_START`  
- `ap_ip_u32` / `ap_gateway_u32` / `ap_netmask_u32` / `ap_station_num` / `ap_stop` / log  
- Implementation: `@[link("ap_idf.c")]` + `@[cimport]`  
- Example: `examples/softap/`  

### Scan (`@v0.3.0` — [104](104-later-tracks-esp-network.md) W2)

- `scan_start(timeout_ms)` — after `sta_init`; blocking `WIFI_EVENT_SCAN_DONE`; keeps up to **16** APs in a fixed C table  
- `scan_max` / `scan_count` — cap / stored count  
- `scan_ssid(index, out, max_len)` — copy SSID into **caller** buffer (NUL-terminated)  
- `scan_rssi` / `scan_channel` / `scan_authmode` / `scan_log`  
- Implementation: same `sta_idf.c` as STA (`scan.kl` wrappers)  
- Example: `examples/scan/`  
- SoftAP-only mode **cannot** scan (needs STA init)

### Link stats (`@v0.4.0` — [104](104-later-tracks-esp-network.md) W3)

- `sta_rssi` / `sta_channel` / `sta_authmode` — after `sta_connected` (`esp_wifi_sta_get_ap_info`; each call → IDF)  
- `sta_ap_ssid(out, max_len)` — associated SSID into **caller** buffer  
- `sta_log_link` — debug printf  
- Example: `examples/sta_connect/` logs link after GOT_IP  

Changelog: `@v0.1.0` STA+DHCP → `@v0.1.1` static → `@v0.2.0` SoftAP → `@v0.3.0` scan → `@v0.4.0` link stats

## Out of scope

- Dual Wi‑Fi+ETH prefer/failover ✅ [113](113-esp-netif-dual-idf.md); APSTA / SoftAP+ETH later → [104](104-later-tracks-esp-network.md); sockets ✅ [111](111-esp-sockets-idf.md); HTTP ✅ [112](112-esp-http-idf.md)  
- BLE — ✅ separate package [`esp_ble`](https://github.com/klin-lang/esp_ble) → [106](106-esp-ble-idf.md) (was track A in [103](103-later-tracks-ble-usb-camera-lcd.md))  
- ESP-NOW — 🔨 sibling [`espnow`](https://github.com/klin-lang/espnow) seed → [159](159-esp-now-idf.md) (not STA/IP)  
- Freestanding (no IDF)  
- Reconnect policy beyond the small, documented retry in `sta_idf.c` (max 5)

## Contract (prime rule)

- No Klin GC / hidden heap — SSID/pass are C strings you pass in; scan/assoc SSID goes into a **caller** buffer.  
- IDF heap / NVS / default event loop / DHCP-or-static / SoftAP DHCPS / scan driver list are **IDF contracts**, documented in the package README.  
- Scan result table max **16** (fixed in C, documented).  
- Link getters call IDF each time (no Klin cache).  
- Errors are `i32` (`esp_err_t`); check them.

## Usage (DHCP — default)

```klin
import "github/klin-lang/esp_wifi" wifi

@[cexport, codename("klin_app_main")]
fn app() {
  let mut e = wifi.sta_init()
  if e != wifi.err_ok() {
    return
  }
  e = wifi.sta_connect("myssid", "mypass")
  if e != wifi.err_ok() {
    return
  }
  e = wifi.sta_wait_connected(15000)
  if e != wifi.err_ok() {
    return
  }
  e = wifi.sta_wait_ip(20000)
  if e != wifi.err_ok() {
    return
  }
  wifi.sta_log_ip_info()
  wifi.sta_log_link()
  let _r = wifi.sta_rssi()
}
```

## Usage (SoftAP)

```klin
import "github/klin-lang/esp_wifi" wifi

@[cexport, codename("klin_app_main")]
fn app() {
  let mut e = wifi.ap_init()
  if e != wifi.err_ok() {
    return
  }
  e = wifi.ap_start("klin-ap", "klinpass1", 6)
  if e != wifi.err_ok() {
    return
  }
  e = wifi.ap_wait_started(5000)
  if e != wifi.err_ok() {
    return
  }
  wifi.ap_log_ip_info()
}
```

## Usage (Scan)

```klin
import "github/klin-lang/esp_wifi" wifi

@[cexport, codename("klin_app_main")]
fn app() {
  let mut e = wifi.sta_init()
  if e != wifi.err_ok() {
    return
  }
  e = wifi.scan_start(15000)
  if e != wifi.err_ok() {
    return
  }
  wifi.scan_log()
  let mut ssid: [33]u8
  let _n = wifi.scan_ssid(0, cast(*mut u8, &ssid[0]), 33)
}
```

## Usage (static IP)

```klin
import "github/klin-lang/esp_wifi" wifi

@[cexport, codename("klin_app_main")]
fn app() {
  let _h = wifi.sta_set_hostname("klin-wifi")
  let _s = wifi.sta_set_static_ip(
    wifi.ipv4(192, 168, 1, 50),
    wifi.ipv4(192, 168, 1, 1),
    wifi.ipv4(255, 255, 255, 0)
  )
  let mut e = wifi.sta_init()
  if e != wifi.err_ok() {
    return
  }
  e = wifi.sta_connect("myssid", "mypass")
  if e != wifi.err_ok() {
    return
  }
  e = wifi.sta_wait_ip(5000)
  if e != wifi.err_ok() {
    return
  }
  wifi.sta_log_ip_info()
}
```

```sh
klin get github/klin-lang/esp_wifi@v0.4.0
```

## Links

- Repo: https://github.com/klin-lang/esp_wifi  
- Tag: [v0.4.0](https://github.com/klin-lang/esp_wifi/releases/tag/v0.4.0)  
- Ethernet sibling: [102](102-esp-eth-idf.md) / [`esp_eth`](https://github.com/klin-lang/esp_eth)  
- Dual Wi‑Fi+ETH glue: [113](113-esp-netif-dual-idf.md) / [`esp_netif_dual`](https://github.com/klin-lang/esp_netif_dual)  
- Network later backlog: [104](104-later-tracks-esp-network.md)  
- Chip MMIO: [099](099-machine-esp-esp32-s3.md) / [`machine_esp`](https://github.com/klin-lang/machine_esp)  
- Board (no radio API): [100](100-board-waveshare-esp32-s3-pico.md)  
- Catalog: [061](061-micropython-machine-api.md), targets [062](062-targets-esp-rp.md)  
- RTOS FFI pattern: [024](024-rtos.md) / [028](028-freertos.md)
