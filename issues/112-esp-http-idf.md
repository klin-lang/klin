# 112 — ESP HTTP(+TLS) as a separate IDF package (`esp_http`)

**Status:** ✅ published `@v0.1.0` (GET/POST + TLS PEM / IDF crt bundle)  
**Depends on:** [021](021-c-libraries.md), [024](024-rtos.md), [049](049-remote-imports.md), [101](101-esp-wifi-idf.md) / [102](102-esp-eth-idf.md) (netif + IP), [104](104-later-tracks-esp-network.md), [111](111-esp-sockets-idf.md) (sockets sibling; not a hard link dep)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | External: [`klin-lang/esp_http`](https://github.com/klin-lang/esp_http) `@v0.1.0` |
| Engine | **ESP-IDF** `esp_http_client` (+ mbedTLS / optional `esp_crt_bundle_attach`) |
| Relation to `esp_sockets` | **Sibling.** Sockets = BSD TCP/UDP. This package = HTTP client API (may use LwIP underneath via IDF). |
| Relation to `esp_wifi` / `esp_eth` | **Separate.** Those own link + IP. Call HTTP **after** GOT_IP. |

Track **N3** from [104](104-later-tracks-esp-network.md).

## Why not fold into `esp_sockets`?

HTTP/TLS is a different contract (headers, status, certs). Keeping it separate matches [104] rule 3 and avoids hiding TLS cost inside raw sockets.

## Scope (`@v0.1.0`)

- `get` / `post` — cleartext HTTP; response → **caller** buffer  
- `get_tls_pem` / `post_tls_pem` — HTTPS with **caller** PEM string  
- `get_tls_bundle` / `post_tls_bundle` — HTTPS with **explicit IDF** x509 crt bundle  
- `last_status` / `last_content_length`  
- `version()` → `1`  
- Implementation: `@[link("http_idf.c")]` + `@[cimport]`  
- Smoke: `examples/smoke/`; sketch: `examples/http_get/`

## Out of scope

- Bringing up Wi‑Fi / ETH  
- Hidden Klin CA store / default insecure HTTPS  
- HTTP server  
- MQTT / OTA (→ [105](105-later-tracks-iot.md))  
- Changing the Klin compiler  

## Contract (prime rule)

- No Klin GC / hidden heap — bodies are caller buffers.  
- No hidden Klin cert store — PEM from you, or IDF crt bundle named at the call site.  
- Truncation if body > `out_max` (returns `out_max`; check `last_content_length`).  
- Transport errors → `-1`; HTTP status via `last_status`.  

## Usage

```klin
import "github/klin-lang/esp_http" http

@[cexport, codename("klin_app_main")]
fn app() {
  // … wifi.sta_wait_ip … first …
  let mut buf: [512]u8
  let n = http.get("http://example.com/", cast(*mut u8, &buf[0]), 512)
  if n < 0 {
    return
  }
  let _st = http.last_status()
}
```

```sh
klin get github/klin-lang/esp_http@v0.1.0
```

## Links

- Repo: https://github.com/klin-lang/esp_http  
- Tag: [v0.1.0](https://github.com/klin-lang/esp_http/releases/tag/v0.1.0)  
- Network later: [104](104-later-tracks-esp-network.md)  
- Sockets: [111](111-esp-sockets-idf.md)  
- IoT later: [105](105-later-tracks-iot.md)  
