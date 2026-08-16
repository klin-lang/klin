# 144 — GD32VW553 HTTP(+TLS PEM) as a separate SDK package (`gd32v_http`)

**Status:** 🔨 Klin surface `@v0.1.0` ready (GET/POST + TLS PEM) — publish when empty [`klin-lang/gd32v_http`](https://github.com/klin-lang/gd32v_http) exists  
**Depends on:** [021](021-c-libraries.md), [024](024-rtos.md), [049](049-remote-imports.md), [137](137-gd32v-wifi-sdk.md) (IP first), [143](143-gd32v-sockets-sdk.md) (sockets sibling; not a hard link dep), [062](062-targets-esp-rp.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | External: [`klin-lang/gd32v_http`](https://github.com/klin-lang/gd32v_http) `@v0.1.0` |
| Engine | Cleartext over **LwIP** sockets; HTTPS via **mbedTLS** + **caller PEM** — not MMIO, **not** ESP-IDF |
| Relation to `gd32v_sockets` | **Sibling.** Sockets = BSD TCP/UDP. This package = HTTP client (may use LwIP underneath). |
| Relation to `gd32v_wifi` | **Separate.** Call HTTP **after** IP. |
| ESP twin | [`esp_http`](https://github.com/klin-lang/esp_http) [112](112-esp-http-idf.md) — VW553 has **no** IDF crt bundle (`*_tls_bundle` omitted) |

## Why not fold into `gd32v_sockets`?

HTTP/TLS is a different contract (headers, status, certs). Keeping it separate matches the ESP split and avoids hiding TLS cost inside raw sockets.

## Scope (`@v0.1.0`)

- `get` / `post` — cleartext HTTP; response → **caller** buffer  
- `get_tls_pem` / `post_tls_pem` — HTTPS with **caller** PEM string (mbedTLS)  
- `last_status` / `last_content_length`  
- `err_ok` / `version()` → `1`  
- **No** `*_tls_bundle` (no IDF-style CA store on this platform)  
- Implementation: `@[link("http_sdk.c")]` + `@[cimport]` (`klin_gd32v_http_*`)  
- Host `klin test` stubs when `lwip/sockets.h` is absent  
- Smoke: `examples/smoke/`; sketch: `examples/http_get/`

## Out of scope

- Bringing up Wi‑Fi / DHCP (→ [137](137-gd32v-wifi-sdk.md))  
- Hidden Klin CA store / default insecure HTTPS  
- HTTP server  
- MQTT / OTA  
- Changing the Klin compiler  
- Using [`esp_http`](https://github.com/klin-lang/esp_http) on VW553 (wrong engine)

## Contract (prime rule)

- No Klin GC / hidden heap — bodies are caller buffers.  
- No hidden Klin cert store — PEM from you only.  
- Truncation if body > `out_max` (returns `out_max`; check `last_content_length`).  
- Transport errors → `-1`; HTTP status via `last_status`.  

## Usage

```klin
import "github/klin-lang/gd32v_wifi" wifi
import "github/klin-lang/gd32v_http" http

fn main() {
    let mut e = wifi.sta_init()
    e = wifi.sta_connect("myssid", "mypass")
    e = wifi.sta_wait_ip(20000)
    if e != wifi.err_ok() {
        return
    }
    let mut buf: [512]u8
    let n = http.get("http://example.com/", cast(*mut u8, &buf[0]), 512)
    if n < 0 {
        return
    }
    let _st = http.last_status()
}
```

```sh
klin get github/klin-lang/gd32v_http@v0.1.0
```

## Links

- Repo: https://github.com/klin-lang/gd32v_http  
- Tag: [v0.1.0](https://github.com/klin-lang/gd32v_http/releases/tag/v0.1.0)  
- Sockets: [143](143-gd32v-sockets-sdk.md)  
- Wi‑Fi: [137](137-gd32v-wifi-sdk.md)  
- ESP twin: [112](112-esp-http-idf.md)  
