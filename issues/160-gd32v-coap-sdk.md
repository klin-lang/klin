# 160 — `gd32v_coap` CoAP client (`@v0.1.0`)

**Status:** 🔨 seed [`patches/gd32v_coap-v0.1.0/`](../patches/gd32v_coap-v0.1.0/)
(awaiting upstream [`klin-lang/gd32v_coap`](https://github.com/klin-lang/gd32v_coap) `@v0.1.0`)  
**Depends on:** [021](021-c-libraries.md), [024](024-rtos.md), [049](049-remote-imports.md),
[137](137-gd32v-wifi-sdk.md) (IP first), [143](143-gd32v-sockets-sdk.md) (UDP sibling; not a hard link dep),
[062](062-targets-esp-rp.md), [105](105-later-tracks-iot.md),
[157](157-later-tracks-gd32v-coap-ws-ibeacon-mesh-cloud.md) V2  
**Parent queue:** [157](157-later-tracks-gd32v-coap-ws-ibeacon-mesh-cloud.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | External: `klin-lang/gd32v_coap`; seed under `patches/` until published |
| Engine | Minimal **RFC 7252** client over **LwIP UDP** — not MMIO, not ESP-IDF, not a libcoap FFI surface |
| Client vs server | **Client only.** No CoAP server in this package. |
| Relation to `gd32v_sockets` | **Sibling.** Sockets = raw TCP/UDP. This package speaks CoAP on UDP. |
| Relation to `gd32v_wifi` | **Separate.** Call **after** IP. |
| Relation to SDK `libcoap` | SDK demos use libcoap; Klin MVP is a fixed-size encode/decode over sockets (same pattern as [146](146-gd32v-mqtt-sdk.md) / [144](144-gd32v-http-sdk.md)). |

## Why not fold into `gd32v_sockets` / `gd32v_http`?

CoAP is a distinct UDP protocol contract (CON/NON, codes, Uri-Path options). Keeping it separate matches [157](157-later-tracks-gd32v-coap-ws-ibeacon-mesh-cloud.md) V2 and the HTTP/MQTT split.

## Scope (`@v0.1.0`)

- `get(uri, out, out_max, confirm)` — `coap://host[:port]/path`; payload → **caller** buffer  
- `put(uri, body, body_len, out, out_max, confirm)` — body is a **caller** buffer  
- `confirm` explicit: `confirm_yes()` / `confirm_no()` (`1` = CON, `0` = NON)  
- `last_code()` — last response code (e.g. `69` = 2.05 Content)  
- `err_ok` / `version()` → `1`  
- Implementation: `@[link("coap_sdk.c")]` + `@[cimport]`  
- Host `klin test` stubs when `lwip/sockets.h` is absent  
- Smoke: `examples/smoke/`; board sketch: `examples/coap_get/`

### Later (not this tag)

- Observe / block-wise transfer / DTLS (`coaps://`)  
- CoAP **server**  
- libcoap FFI thin wrap (only if a desk project needs features beyond MVP)

## Out of scope

- Bringing up Wi‑Fi (→ [137](137-gd32v-wifi-sdk.md))  
- WebSocket / Wi‑Fi Mesh / cloud ([157](157-later-tracks-gd32v-coap-ws-ibeacon-mesh-cloud.md) V3+; WS → [161](161-gd32v-websocket-sdk.md))  
- Folding into `machine_gd32v` or board packs  
- Vendoring `GD32VW55x_WiFi_BLE_SDK` / libcoap into the package tree  
- Changing the Klin compiler  

## Contract (prime rule)

- No Klin GC / hidden heap — URI and payloads are caller args / buffers; request/response use fixed C packet buffers (max 512).  
- Confirm vs non-confirm is an **argument**, not a hidden mode.  
- LwIP / DNS / UDP timeouts are **SDK / OS contracts**.  
- Errors → `-1`.  

## Usage (after Wi‑Fi IP)

```sh
klin get github/klin-lang/gd32v_coap@v0.1.0
```

Until publish:

```sh
klin test patches/gd32v_coap-v0.1.0/gd32v_coap
```

```klin
import "github/klin-lang/gd32v_coap" coap

fn main() {
    let mut out: [256]u8
    let mut n = coap.get(
        "coap://127.0.0.1/test",
        cast(*mut u8, &out[0]),
        256,
        coap.confirm_yes()
    )
}
```

## Links

- Seed: [`patches/gd32v_coap-v0.1.0/`](../patches/gd32v_coap-v0.1.0/)  
- Planned repo: https://github.com/klin-lang/gd32v_coap  
- SDK example: `MSDK/examples/wifi/coap`  
- Wi‑Fi / sockets / HTTP / MQTT: [137](137-gd32v-wifi-sdk.md), [143](143-gd32v-sockets-sdk.md), [144](144-gd32v-http-sdk.md), [146](146-gd32v-mqtt-sdk.md)  
- Queue: [157](157-later-tracks-gd32v-coap-ws-ibeacon-mesh-cloud.md)
