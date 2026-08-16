# gd32v_http

Thin **GD32VW55x HTTP(+TLS PEM)** client for [Klin](https://github.com/klin-lang/klin).

**Does not** bring up Wi‑Fi — get an IP first with
[`gd32v_wifi`](https://github.com/klin-lang/gd32v_wifi). Sockets sibling:
[`gd32v_sockets`](https://github.com/klin-lang/gd32v_sockets). Same split as ESP
[`esp_http`](https://github.com/klin-lang/esp_http) vs `esp_wifi`
(Klin [112](https://github.com/klin-lang/klin/blob/main/issues/112-esp-http-idf.md) /
[144](https://github.com/klin-lang/klin/blob/main/issues/144-gd32v-http-sdk.md)).

C engine = cleartext over LwIP sockets; HTTPS via **mbedTLS** with a **caller PEM**.
No IDF-style certificate bundle on this platform. Klin is a thin FFI client
(`@[link("http_sdk.c")]` + `@[cimport]`). Response body is always a **caller buffer**.

**Not** [`esp_http`](https://github.com/klin-lang/esp_http) — that is ESP-IDF.

## Status (`@v0.1.0`)

| API | Notes |
|---|---|
| `get` / `post` | Cleartext HTTP; body/out = caller buffers |
| `get_tls_pem` / `post_tls_pem` | HTTPS + caller PEM string |
| `last_status` / `last_content_length` | After last exchange |
| `err_ok` / `version` | Helpers (`version()` → `1`) |

No `*_tls_bundle` (VW55x has no IDF crt bundle — pass PEM).

## Requirements

- [Klin](https://github.com/klin-lang/klin) compiler
- [GD32VW55x_WiFi_BLE_SDK](https://github.com/GigaDeviceSemiconductor/GD32VW55x_WiFi_BLE_SDK) with LwIP (+ mbedTLS for HTTPS)
- Live STA/SoftAP IP via [`gd32v_wifi`](https://github.com/klin-lang/gd32v_wifi) before requests

## Usage (after Wi‑Fi IP)

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

HTTPS with caller PEM:

```klin
let n = http.get_tls_pem("https://example.com/", ca_pem, cast(*mut u8, &buf[0]), 512)
```

```sh
klin get github/klin-lang/gd32v_http@v0.1.0
```

## Contract (prime rule)

- No Klin GC / hidden heap — request/response payloads are yours.
- No hidden Klin cert store — PEM from the caller only.
- Truncation: if body > `out_max`, returns `out_max` bytes (check `last_content_length`).
- Errors: `-1` on client/transport failure; inspect `last_status` after headers.
- Does not configure Wi‑Fi, DHCP, or sockets directly (uses LwIP under the hood).

## Tests

```sh
dart run /path/to/klin/bin/klin.dart test gd32v_http/
```

Host `klin test` uses stubs when `lwip/sockets.h` is not on the include path.

## Changelog

| Tag | Notes |
|---|---|
| `@v0.1.0` | GET/POST + TLS PEM |

## Links

- Sockets: https://github.com/klin-lang/gd32v_sockets
- Wi‑Fi: https://github.com/klin-lang/gd32v_wifi
- ESP twin: https://github.com/klin-lang/esp_http
