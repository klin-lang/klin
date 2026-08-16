# 137 — GD32VW553 Wi‑Fi as a separate SDK package (`gd32v_wifi`)

**Status:** 🔨 STA + SoftAP + scan + link + static + APSTA + roaming + WPS + EAP-TLS published [`@v0.7.0`](https://github.com/klin-lang/gd32v_wifi/releases/tag/v0.7.0)  
**Depends on:** [021](021-c-libraries.md), [024](024-rtos.md), [049](049-remote-imports.md), [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md), [136](136-machine-gd32v-gd32vw553.md)
**Formerly:** `126` (renumbered to resolve duplicate issue numbers).

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | External: [`klin-lang/gd32v_wifi`](https://github.com/klin-lang/gd32v_wifi) `@v0.7.0` |
| Engine | **GigaDevice VW55x Wi‑Fi BLE SDK** (`wifi_management` / `wifi_net_ip` / lwIP / OSAL) — not MMIO, **not** ESP-IDF |
| Relation to `machine_gd32v` | **Separate.** [136](136-machine-gd32v-gd32vw553.md) Pin…Adc twins stay MMIO. Same split as [`esp_wifi`](https://github.com/klin-lang/esp_wifi) vs `machine_esp` ([101](101-esp-wifi-idf.md)). |
| BLE | Sibling [`gd32v_ble`](https://github.com/klin-lang/gd32v_ble) [140](140-gd32v-ble-sdk.md) (advertise+GATT+scan/connect+gattc+jw-bond+uuid16+passkey+uuid128/multi+privacy+mesh+prov+level+friend+oob+string+friendparams+vndbyte `@v0.15.0`) — same split as [106](106-esp-ble-idf.md) |

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

Default IP mode = **DHCP** (SDK management starts DHCP after assoc). Static IP → `@v0.4.0`.

## Scope (`@v0.2.0` — SoftAP)

- `ap_init` — same `wifi_management_init` (once)  
- `ap_start(ssid, pass, channel)` — `wifi_management_ap_start` (AN158 §5.3 / §4.4.8). Channel `1`…`13`. Empty pass = `AUTH_MODE_OPEN`; else `AUTH_MODE_WPA2` (password length 8…63). `hidden=0` (broadcast SSID). Do **not** pass a `"wpa2"` string — AN158 table 5-4 is a doc bug; the API takes `wifi_ap_auth_mode_t`.  
- `ap_wait_started` / `ap_started` — last `ap_start` result (`i32` 1/0, same as `sta_connected`)  
- `ap_wait_ip(timeout_ms)` — poll `wifi_get_vif_ip` (vif 0)  
- `ap_ip_u32` / `ap_gateway_u32` / `ap_netmask_u32` / `ap_log_ip_info`  
- `ap_stop` — `wifi_management_ap_stop` (does **not** `deinit`; `sta_stop` still deinit)  
- Implementation: `@[link("ap_sdk.c")]` + `@[cimport]` (no `@[cinclude]`)  
- Example `examples/softap/` — needs the official SDK to link an ELF  
- SoftAP-only on this tag — do **not** mix `sta_*` and `ap_*` until `@v0.5.0` (`concurrent_set(1)`) — see below  

Default AP IPv4 = SDK SoftAP (typically `192.168.4.1` + DHCPS). `ap_set_ip` / `ap_station_num` → `@v0.4.0`.

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

## Scope (`@v0.4.0` — link + static + SoftAP extras)

- `sta_rssi` / `sta_channel` / `sta_authmode` / `sta_ap_ssid(out, max_len)` / `sta_log_link` — after `sta_connected`. Each call → SDK (`macif_vif_sta_rssi_get` / `macif_vif_current_chan_get` / `wifi_vif_tab[0].sta.cfg`). Associated SSID into **caller** buffer.  
- `sta_set_static_ip(ip, gw, mask)` — optional `wifi_set_vif_ip` / `IP_ADDR_STATIC_IPV4`. `0,0,0` = DHCP (default). Prefer before `sta_connect`.  
- `sta_set_hostname(name)` — optional `wifi_vif_hostname_set` (vif 0). Empty = SDK default.  
- `ap_set_ip(ip, gw, mask)` — optional SoftAP IPv4 + DHCPS (`IP_ADDR_DHCP_SERVER`). `0,0,0` = SDK default. Prefer before `ap_start`.  
- `ap_station_num` — associated STA count (`macif_vif_ap_assoc_info_get`; AN158 example treats the return as a count).  
- Host stubs: after DHCP connect still `192.168.1.50`; after static then connect, those packed `u32`s; link rssi `-42` / ch `6` / auth `3`; `ap_station_num` → `0`.  
- `version()` → `4`

Changelog: `@v0.1.0` STA+DHCP → `@v0.2.0` SoftAP → `@v0.3.0` scan → `@v0.4.0` link+static+AP extras

## Scope (`@v0.5.0` — APSTA)

- `concurrent_supported` — 1 if SDK built with `CFG_WIFI_CONCURRENT` (`wlan_config.h`)  
- `concurrent_set(enable)` / `concurrent()` — `wifi_management_concurrent_set` / `get` (AN158 §4.4.10 / §4.4.11)  
- Call **`sta_init` or `ap_init` once** to open management; then `concurrent_set(1)`; then mix `sta_*` + `ap_*`  
- The other `*_init` after management is already open is **attach-only** (does not call `wifi_management_init` again)  
- SoftAP uses **vif 1** while STA stays **vif 0** (`WIFI_VIF_INDEX_SOFTAP_MODE`)  
- `ap_wait_ip` / `ap_ip_u32` / `ap_gateway_u32` / `ap_netmask_u32` / `ap_log_ip_info` / `ap_station_num` use the SoftAP vif (**1** when concurrent; **0** SoftAP-only)  
- SoftAP channel follows STA when linked (SDK may rewrite the channel)  
- Without `CFG_WIFI_CONCURRENT` → `concurrent_supported` is false / `concurrent_set` → `-1`  
- `version()` → `5`  
- Example `examples/apsta/`  

Changelog: … → `@v0.4.0` link+static → `@v0.5.0` APSTA

## Scope (`@v0.6.0` — roaming)

- `roaming_set(enable, rssi_th)` — `wifi_management_roaming_set` after `sta_init`  
- `rssi_th` is int8 dBm (e.g. `-70`); when enabling, `0` keeps the prior threshold (SDK behavior)  
- `roaming` / `roaming_rssi_th` — enable flag + current threshold  
- Engine: SDK preroam when RSSI drops below threshold (same ESS / BSSID switch is an **SDK contract**)  
- `version()` → `6`  
- Example `examples/roaming/`  

Changelog: … → `@v0.5.0` APSTA → `@v0.6.0` roaming

## Scope (`@v0.7.0` — WPS + EAP-TLS)

- `wps_supported` — 1 if SDK built with `CFG_WPS`  
- `wps_pbc` / `wps_pin(pin)` — `wifi_management_wps_start` blocked (AN158 §4.4.16). PIN length **4..=8**. After `sta_init`. Without `CFG_WPS` → `-1`  
- `eap_tls_supported` — 1 if SDK built with `CFG_8021x_EAP_TLS`  
- `sta_connect_eap_tls(ssid, identity, ca_cert, client_key, client_cert, client_key_password, phase1)` — `wifi_management_connect_with_eap_tls` blocked. PEM strings are **caller-owned** C strings; empty key password / phase1 → NULL. Without `CFG_8021x_EAP_TLS` → `-1`  
- **Board note:** WPS / EAP-TLS need an **msdk_ffd** (or `msdk_ffd_threadx`) SDK image with full `libwpa_supplicant` (AN154). Default **msdk** links slim `libwpas` and does **not** provide these even if macros are toggled alone.  
- `version()` → `7`  
- Examples `examples/wps/` / `examples/eap_tls/`  

Changelog: … → `@v0.6.0` roaming → `@v0.7.0` WPS+EAP-TLS

## Out of scope (this tag)

- BLE — [`gd32v_ble`](https://github.com/klin-lang/gd32v_ble) [140](140-gd32v-ble-sdk.md) (AN152), not this package  
- Sockets / HTTP / MQTT  
- Board pack / `klin init` — [`gd32vw553h_eval`](https://github.com/klin-lang/gd32vw553h_eval) [138](138-board-gd32vw553h-eval.md) (no radio API there)  
- Vendoring `GD32VW55x_WiFi_BLE_SDK`  
- Using [`esp_wifi`](https://github.com/klin-lang/esp_wifi) on VW553 (wrong engine)

## Contract (prime rule)

- No Klin GC / hidden heap — SSID/pass/PIN/PEM are C strings you pass in; scan SSID goes into a **caller** buffer.  
- SDK heap / OSAL task / eloop / lwIP DHCP / SoftAP DHCPS / concurrent / roaming / WPS / EAP-TLS / scan result list malloc are **SDK contracts**, documented in the package README.  
- APSTA needs explicit `concurrent_set(1)` and `CFG_WIFI_CONCURRENT`. WPS needs `CFG_WPS` + **msdk_ffd** (`libwpa_supplicant`); EAP-TLS needs `CFG_8021x_EAP_TLS` + **msdk_ffd**.  
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
    wifi.sta_log_link()
}
```

Optional static IPv4 (prefer before `sta_connect`):

```klin
    let _h = wifi.sta_set_hostname("klin-wifi")
    let _s = wifi.sta_set_static_ip(
        wifi.ipv4(10, 0, 0, 20),
        wifi.ipv4(10, 0, 0, 1),
        wifi.ipv4(255, 255, 255, 0)
    )
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
    let _n = wifi.ap_station_num()
}
```

Optional AP IPv4 + DHCPS (prefer before `ap_start`):

```klin
    let _ip = wifi.ap_set_ip(
        wifi.ipv4(192, 168, 8, 1),
        wifi.ipv4(192, 168, 8, 1),
        wifi.ipv4(255, 255, 255, 0)
    )
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

## Usage (APSTA)

```klin
import "github/klin-lang/gd32v_wifi" wifi

fn main() {
    let mut e = wifi.sta_init()
    e = wifi.concurrent_set(1)
    e = wifi.sta_connect("myssid", "mypass")
    e = wifi.sta_wait_ip(20000)
    e = wifi.ap_init() /* attach SoftAP client; management already open */
    e = wifi.ap_start("klin-ap", "klinpass1", 6)
    e = wifi.ap_wait_ip(5000) /* SoftAP vif 1 */
}
```

## Usage (WPS)

```klin
import "github/klin-lang/gd32v_wifi" wifi

fn main() {
    let mut e = wifi.sta_init()
    if e != wifi.err_ok() {
        return
    }
    if !wifi.wps_supported() {
        return
    }
    e = wifi.wps_pbc()
    // e = wifi.wps_pin("12345670")
    if e != wifi.err_ok() {
        return
    }
    e = wifi.sta_wait_ip(30000)
}
```

## Usage (EAP-TLS)

```klin
import "github/klin-lang/gd32v_wifi" wifi

fn main() {
    let mut e = wifi.sta_init()
    if e != wifi.err_ok() {
        return
    }
    if !wifi.eap_tls_supported() {
        return
    }
    e = wifi.sta_connect_eap_tls(
        "corp-ssid", "user@example.com",
        "-----BEGIN CERTIFICATE-----\nCA\n-----END CERTIFICATE-----\n",
        "-----BEGIN PRIVATE KEY-----\nKEY\n-----END PRIVATE KEY-----\n",
        "-----BEGIN CERTIFICATE-----\nCLIENT\n-----END CERTIFICATE-----\n",
        "", ""
    )
    if e != wifi.err_ok() {
        return
    }
    e = wifi.sta_wait_ip(30000)
}
```

## Usage (roaming)

```klin
import "github/klin-lang/gd32v_wifi" wifi

fn main() {
    let mut e = wifi.sta_init()
    e = wifi.roaming_set(1, 0 - 70)
    e = wifi.sta_connect("myssid", "mypass")
    e = wifi.sta_wait_ip(20000)
}
```

```sh
klin get github/klin-lang/gd32v_wifi@v0.7.0
```

## Links

- Package: https://github.com/klin-lang/gd32v_wifi  
- Tag: [v0.7.0](https://github.com/klin-lang/gd32v_wifi/releases/tag/v0.7.0) (roaming [v0.6.0](https://github.com/klin-lang/gd32v_wifi/releases/tag/v0.6.0), APSTA [v0.5.0](https://github.com/klin-lang/gd32v_wifi/releases/tag/v0.5.0), link+static [v0.4.0](https://github.com/klin-lang/gd32v_wifi/releases/tag/v0.4.0), scan [v0.3.0](https://github.com/klin-lang/gd32v_wifi/releases/tag/v0.3.0), SoftAP [v0.2.0](https://github.com/klin-lang/gd32v_wifi/releases/tag/v0.2.0), STA [v0.1.0](https://github.com/klin-lang/gd32v_wifi/releases/tag/v0.1.0))  
- SDK: https://github.com/GigaDeviceSemiconductor/GD32VW55x_WiFi_BLE_SDK  
- AN158 Wi‑Fi Development Guide (GigaDevice)  
- Chip MMIO: [136](136-machine-gd32v-gd32vw553.md) / [`machine_gd32v`](https://github.com/klin-lang/machine_gd32v)  
- Board pack: [138](138-board-gd32vw553h-eval.md) / [`gd32vw553h_eval`](https://github.com/klin-lang/gd32vw553h_eval)  
- ESP radio sibling (different engine): [101](101-esp-wifi-idf.md)  
- Catalog: [061](061-micropython-machine-api.md), targets [062](062-targets-esp-rp.md)  
