# 126 — GD32VW553 Wi‑Fi as a separate SDK package (`gd32v_wifi`)

**Status:** 🔨 STA + SoftAP + scan published [`@v0.3.0`](https://github.com/klin-lang/gd32v_wifi/releases/tag/v0.3.0) (assoc RSSI / BLE later)  
**Depends on:** [021](021-c-libraries.md), [024](024-rtos.md), [049](049-remote-imports.md), [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md), [117](117-machine-gd32v-gd32vw553.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | External: [`klin-lang/gd32v_wifi`](https://github.com/klin-lang/gd32v_wifi) `@v0.3.0` |
| Engine | **GigaDevice VW55x Wi‑Fi BLE SDK** (`wifi_management` / `wifi_net_ip` / lwIP / OSAL) — not MMIO, **not** ESP-IDF |
| Relation to `machine_gd32v` | **Separate.** [117](117-machine-gd32v-gd32vw553.md) Pin…Adc twins stay MMIO. Same split as [`esp_wifi`](https://github.com/klin-lang/esp_wifi) vs `machine_esp` ([101](101-esp-wifi-idf.md)). |
| BLE | Sibling [`gd32v_ble`](https://github.com/klin-lang/gd32v_ble) [130](130-gd32v-ble-sdk.md) (advertise `@v0.1.0`) — same split as [106](106-esp-ble-idf.md) |

## Why not `machine_gd32v.Wifi`?

[`machine_gd32v`](https://github.com/klin-lang/machine_gd32v) is thin Klin over **explicit MMIO**. VW553 Wi‑Fi 6 needs the GigaDevice wireless SDK (management task, eloop, lwIP, RF blobs). Folding that into `machine_*` would hide SDK heap / tasks / DHCP and break the MMIO contract. Pattern matches [`esp_wifi`](https://github.com/klin-lang/esp_wifi) / [`klin_freertos`](https://github.com/klin-lang/klin_freertos): C engine + Klin FFI client ([024](024-rtos.md)).

Do **not** vendor the full SDK inside Klin or this package. The example expects
[`GD32VW55x_WiFi_BLE_SDK`](https://github.com/GigaDeviceSemiconductor/GD32VW55x_WiFi_BLE_SDK)
on the include/link path (AN158).

## Scope (`@v0.1.0` — STA)

- `sta_init` — `wifi_management_init` (LwIP + eloop + management task; call once)  
- `sta_connect(ssid, pass)` — `wifi_management_connect(..., blocked=1)` (AN158 §5.2)  
- `sta_wait_connected` / `sta_connected` — last connect result (blocked connect)  
- `sta_wait_ip(timeout_ms)` — poll `wifi_get_vif_ip` (vif 0) until `ipv4.addr != 0` (`-1` = forever)  
- `sta_ip_u32` / `sta_gateway_u32` / `sta_netmask_u32` / `sta_log_ip_info`  
- `sta_disconnect` / `sta_stop` — `wifi_management_disconnect` / `wifi_management_deinit`  
- `err_ok` / `ipv4` — same shape as [`esp_wifi`](https://github.com/klin-lang/esp_wifi)  
- Implementation: `@[link("sta_sdk.c")]` + `@[cimport]` (no SDK header parser)  
- Host tests use the C file **without** SDK headers (`__has_include` stubs)  
- Example `examples/sta_connect/` — needs the official SDK to link an ELF  

Default IP mode = **DHCP** (SDK management starts DHCP after assoc). Static IP later.

## Scope (`@v0.2.0` — SoftAP)

- `ap_init` — same `wifi_management_init` (once)  
- `ap_start(ssid, pass, channel)` — `wifi_management_ap_start` (AN158 §5.3 / §4.4.8). Channel `1`…`13`. Empty pass = `AUTH_MODE_OPEN`; else `AUTH_MODE_WPA2` (password length 8…63). `hidden=0` (broadcast SSID). Do **not** pass a `"wpa2"` string — AN158 table 5-4 is a doc bug; the API takes `wifi_ap_auth_mode_t`.  
- `ap_wait_started` / `ap_started` — last `ap_start` result (`i32` 1/0, same as `sta_connected`)  
- `ap_wait_ip(timeout_ms)` — poll `wifi_get_vif_ip` (vif 0)  
- `ap_ip_u32` / `ap_gateway_u32` / `ap_netmask_u32` / `ap_log_ip_info`  
- `ap_stop` — `wifi_management_ap_stop` (does **not** `deinit`; `sta_stop` still deinit)  
- Implementation: `@[link("ap_sdk.c")]` + `@[cimport]` (no `@[cinclude]`)  
- Example `examples/softap/` — needs the official SDK to link an ELF  
- SoftAP-only on this tag — do **not** mix `sta_*` and `ap_*` (APSTA later)  

Default AP IPv4 = SDK SoftAP (typically `192.168.4.1` + DHCPS). `ap_set_ip` / `ap_station_num` later.

Changelog: `@v0.1.0` STA+DHCP → `@v0.2.0` SoftAP

## Scope (`@v0.3.0` — scan)

- `scan_start(timeout_ms)` — after `sta_init`; `wifi_management_scan(blocked=1, ssid=NULL)` (AN158 §5.1 / §4.4.3). `timeout_ms` unused — the SDK blocks until done (kept for [`esp_wifi`](https://github.com/klin-lang/esp_wifi) shape).  
- `scan_max` / `scan_count` — cap **16** / stored count  
- `scan_ssid(index, out, max_len)` — copy SSID into **caller** buffer (NUL-terminated)  
- `scan_rssi` / `scan_channel` / `scan_authmode` / `scan_log` — channel from `mac_chan_def.freq`; auth = `wifi_ap_auth_mode_t` (0 = OPEN, 3 = WPA2, …)  
- Implementation: same `sta_sdk.c` as STA (`scan.kl` wrappers). Results via `wifi_netlink_scan_results_print` (SDK malloc of the result list is an **SDK contract**).  
- Example `examples/scan/` — needs the official SDK to link an ELF  
- SoftAP-only mode **cannot** scan (needs `sta_init`, not `ap_init`)

Changelog: `@v0.1.0` STA+DHCP → `@v0.2.0` SoftAP → `@v0.3.0` scan

## Out of scope (this tag)

- Associated-AP RSSI / channel / auth (`sta_rssi` later) / APSTA / roaming / WPS / EAP-TLS  
- Static IPv4 (`wifi_set_vif_ip`) / `ap_set_ip` / `ap_station_num`  
- BLE — [`gd32v_ble`](https://github.com/klin-lang/gd32v_ble) [130](130-gd32v-ble-sdk.md) (AN152), not this package  
- Sockets / HTTP / MQTT  
- Board pack / `klin init` — [`gd32vw553h_eval`](https://github.com/klin-lang/gd32vw553h_eval) [127](127-board-gd32vw553h-eval.md) (no radio API there)  
- Vendoring `GD32VW55x_WiFi_BLE_SDK`  
- Using [`esp_wifi`](https://github.com/klin-lang/esp_wifi) on VW553 (wrong engine)

## Contract (prime rule)

- No Klin GC / hidden heap — SSID/pass are C strings you pass in; scan SSID goes into a **caller** buffer.  
- SDK heap / OSAL task / eloop / lwIP DHCP / SoftAP DHCPS / scan result list malloc are **SDK contracts**, documented in the package README.  
- Scan result table max **16** (fixed in C, documented).  
- Errors are `i32` (0 = ok, same as `wifi_management_*`).  
- Host `klin test` must not require the SDK tree.

## Usage (STA)

```klin
import "github/klin-lang/gd32v_wifi" wifi

fn main() {
    let mut e = wifi.sta_init()
    if e != wifi.err_ok() {
        return
    }
    e = wifi.sta_connect("myssid", "mypass")
    if e != wifi.err_ok() {
        return
    }
    e = wifi.sta_wait_ip(20000)
    if e != wifi.err_ok() {
        return
    }
    wifi.sta_log_ip_info()
}
```

## Usage (SoftAP)

```klin
import "github/klin-lang/gd32v_wifi" wifi

fn main() {
    let mut e = wifi.ap_init()
    if e != wifi.err_ok() {
        return
    }
    e = wifi.ap_start("klin-ap", "klinpass1", 6)
    if e != wifi.err_ok() {
        return
    }
    e = wifi.ap_wait_ip(5000)
    if e != wifi.err_ok() {
        return
    }
    wifi.ap_log_ip_info()
}
```

## Usage (scan)

```klin
import "github/klin-lang/gd32v_wifi" wifi

fn main() {
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

```sh
klin get github/klin-lang/gd32v_wifi@v0.3.0
```

## Links

- Package: https://github.com/klin-lang/gd32v_wifi  
- Tag: [v0.3.0](https://github.com/klin-lang/gd32v_wifi/releases/tag/v0.3.0) (SoftAP [v0.2.0](https://github.com/klin-lang/gd32v_wifi/releases/tag/v0.2.0), STA [v0.1.0](https://github.com/klin-lang/gd32v_wifi/releases/tag/v0.1.0))  
- SDK: https://github.com/GigaDeviceSemiconductor/GD32VW55x_WiFi_BLE_SDK  
- AN158 Wi‑Fi Development Guide (GigaDevice)  
- Chip MMIO: [117](117-machine-gd32v-gd32vw553.md) / [`machine_gd32v`](https://github.com/klin-lang/machine_gd32v)  
- Board pack: [127](127-board-gd32vw553h-eval.md) / [`gd32vw553h_eval`](https://github.com/klin-lang/gd32vw553h_eval)  
- ESP radio sibling (different engine): [101](101-esp-wifi-idf.md)  
- Catalog: [061](061-micropython-machine-api.md), targets [062](062-targets-esp-rp.md)  
