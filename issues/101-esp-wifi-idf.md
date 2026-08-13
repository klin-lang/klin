# 101 — ESP Wi‑Fi as a separate IDF package (`esp_wifi`)

**Status:** ✅ published `@v0.1.0`  
**Depends on:** [021](021-c-libraries.md), [024](024-rtos.md), [049](049-remote-imports.md), [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md), [099](099-machine-esp-esp32-s3.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | External: [`klin-lang/esp_wifi`](https://github.com/klin-lang/esp_wifi) `@v0.1.0` |
| Engine | **ESP-IDF** v5.x (`esp_wifi` / netif / event loop / NVS) — not MMIO |
| Relation to `machine_esp` | **Separate.** Radio is in silicon; `machine_*` MVP stays Pin…Adc(+Rmt). Same split as µPython `machine` vs `network` ([061](061-micropython-machine-api.md)). |

## Why not `machine_esp.Wifi`?

[`machine_esp`](https://github.com/klin-lang/machine_esp) is approach **C** — thin Klin over **explicit MMIO**. Wi‑Fi needs the IDF stack (NVS, netif, event loop, firmware blobs). Folding that into `machine_*` would hide IDF cost and break the MMIO contract. Pattern matches [`klin_freertos`](https://github.com/klin-lang/klin_freertos): C engine + Klin FFI client ([024](024-rtos.md)).

Board pack [100](100-board-waveshare-esp32-s3-pico.md) stays pins/WS2812/buses — **no** radio API there either.

## Scope (`@v0.1.0`)

- `sta_init` — NVS + netif + default event loop + `esp_wifi_init` + STA mode  
- `sta_connect(ssid, pass)` — fill `wifi_config_t`, start, connect  
- `sta_wait_ip(timeout_ms)` — explicit wait on GOT_IP (`-1` = forever)  
- `sta_ip_u32` / `sta_log_ip` — IPv4 after wait  
- `sta_disconnect` / `sta_stop`  
- Implementation: `@[link("sta_idf.c")]` + `@[cimport]` (no IDF header parser)  
- Example: `examples/sta_connect/` (ESP32-S3, `idf.py`)

## Out of scope

- SoftAP  
- BLE  
- LwIP sockets / HTTP / TLS  
- Freestanding (no IDF)  
- Reconnect policy beyond the small, documented retry in `sta_idf.c` (max 5)

## Contract (prime rule)

- No Klin GC / hidden heap — SSID/pass are C strings you pass in.  
- IDF heap / NVS / default event loop are **IDF contracts**, documented in the package README.  
- Errors are `i32` (`esp_err_t`); check them.

## Usage

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
  e = wifi.sta_wait_ip(20000)
  if e != wifi.err_ok() {
    return
  }
  wifi.sta_log_ip()
}
```

```sh
klin get github/klin-lang/esp_wifi@v0.1.0
```

## Links

- Repo: https://github.com/klin-lang/esp_wifi  
- Tag: [v0.1.0](https://github.com/klin-lang/esp_wifi/releases/tag/v0.1.0)  
- Chip MMIO: [099](099-machine-esp-esp32-s3.md) / [`machine_esp`](https://github.com/klin-lang/machine_esp)  
- Board (no radio API): [100](100-board-waveshare-esp32-s3-pico.md)  
- Catalog: [061](061-micropython-machine-api.md), targets [062](062-targets-esp-rp.md)  
- RTOS FFI pattern: [024](024-rtos.md) / [028](028-freertos.md)
