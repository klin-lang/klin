# 161 — `gd32v_websocket` WebSocket client (`@v0.1.0`)

**Status:** 🔨 seed [`patches/gd32v_websocket-v0.1.0/`](../patches/gd32v_websocket-v0.1.0/)
(awaiting upstream [`klin-lang/gd32v_websocket`](https://github.com/klin-lang/gd32v_websocket) `@v0.1.0`)  
**Depends on:** [021](021-c-libraries.md), [024](024-rtos.md), [049](049-remote-imports.md),
[137](137-gd32v-wifi-sdk.md) (IP first), [143](143-gd32v-sockets-sdk.md) (TCP sibling; not a hard link dep),
[062](062-targets-esp-rp.md), [105](105-later-tracks-iot.md),
[157](157-later-tracks-gd32v-coap-ws-ibeacon-mesh-cloud.md) V3  
**Parent queue:** [157](157-later-tracks-gd32v-coap-ws-ibeacon-mesh-cloud.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | External: `klin-lang/gd32v_websocket`; seed under `patches/` until published |
| Engine | Minimal **RFC 6455** client over **LwIP TCP** — not MMIO, not ESP-IDF, not a tinyws FFI surface |
| Client vs server | **Client only.** |
| Relation to `gd32v_sockets` / `gd32v_http` | **Sibling.** Sockets = raw TCP/UDP; HTTP = request/response; this package is a persistent framed duplex. |
| Relation to SDK `tinyws` | SDK demos use tinyws; Klin MVP is fixed-size handshake + masked frames (same pattern as [160](160-gd32v-coap-sdk.md) / [146](146-gd32v-mqtt-sdk.md)). |

## Scope (`@v0.1.0`)

- `connect(uri)` — `ws://host[:port]/path` (default port **80**)  
- `disconnect` / `connected`  
- `send_text` / `send_bin` — caller payload; client frames **masked**  
- `recv(out, out_max)` — one data frame → caller buffer; `0` = none/timeout; `-1` = error/closed  
- PING answered with PONG inside C (not returned to Klin)  
- `last_opcode` / `opcode_text` / `opcode_bin`  
- `err_ok` / `version()` → `1`  
- Host stubs when `lwip/sockets.h` absent  
- Smoke: `examples/smoke/`; sketch: `examples/ws_echo/`

### Later (not this tag)

- `wss://` + caller PEM (same rule as [144](144-gd32v-http-sdk.md))  
- Fragmented frames / large payloads / compression  
- WebSocket **server**  
- tinyws FFI wrap (only if a desk project needs it)

## Out of scope

- Bringing up Wi‑Fi (→ [137](137-gd32v-wifi-sdk.md))  
- Wi‑Fi Mesh / cloud ([157](157-later-tracks-gd32v-coap-ws-ibeacon-mesh-cloud.md) V4+; Mesh → [162](162-gd32v-wifi-mesh-sdk.md))  
- Folding into `machine_gd32v` or board packs  
- Vendoring `GD32VW55x_WiFi_BLE_SDK` / tinyws into the package tree  

## Contract (prime rule)

- No Klin GC / hidden heap — URI and payloads are caller args / buffers; I/O uses fixed C buffers (max 1024).  
- LwIP / DNS / TCP timeouts are **SDK / OS contracts**.  
- Errors → `-1`.  

## Usage (after Wi‑Fi IP)

```sh
klin get github/klin-lang/gd32v_websocket@v0.1.0
```

Until publish:

```sh
klin test patches/gd32v_websocket-v0.1.0/gd32v_websocket
```

## Links

- Seed: [`patches/gd32v_websocket-v0.1.0/`](../patches/gd32v_websocket-v0.1.0/)  
- Planned repo: https://github.com/klin-lang/gd32v_websocket  
- SDK example: `MSDK/examples/wifi/websocket_client`  
- CoAP sibling: [160](160-gd32v-coap-sdk.md)  
- Queue: [157](157-later-tracks-gd32v-coap-ws-ibeacon-mesh-cloud.md)
