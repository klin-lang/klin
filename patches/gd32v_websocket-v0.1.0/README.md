# gd32v_websocket

Thin **GD32VW55x WebSocket (RFC 6455) client** for
[Klin](https://github.com/klin-lang/klin).

**Client only** — not a server. **Does not** bring up Wi‑Fi — get an IP first
with [`gd32v_wifi`](https://github.com/klin-lang/gd32v_wifi). Sibling of
[`gd32v_sockets`](https://github.com/klin-lang/gd32v_sockets) /
[`gd32v_http`](https://github.com/klin-lang/gd32v_http).

C engine = minimal WebSocket handshake + masked frames over **LwIP TCP**
(when `lwip/sockets.h` is on the include path). Klin is a thin FFI client
(`@[link("ws_sdk.c")]` + `@[cimport]`). Payloads are **caller buffers**.

**`@v0.1.0`:** cleartext `ws://` only. `wss://` + caller PEM = later tag
(same rule as [`gd32v_http`](https://github.com/klin-lang/gd32v_http)).

Not a tinyws FFI wrapper (SDK ships `MSDK/lwip/tinyws` for its demos). Not
ESP-IDF.

## Status (`@v0.1.0`)

| API | Notes |
|---|---|
| `connect` / `disconnect` / `connected` | URI `ws://host[:port]/path` (default port 80) |
| `send_text` / `send_bin` | Caller payload; client frames are masked |
| `recv` | One data frame → caller buffer; `0` = none/timeout; PING→PONG in C |
| `last_opcode` / `opcode_text` / `opcode_bin` | `1` / `2` after `recv` |
| `err_ok` / `version` | Helpers (`version()` → `1`) |

## Requirements

- [Klin](https://github.com/klin-lang/klin) compiler
- LwIP sockets (GD32VW55x Wi‑Fi BLE SDK) for on-device TCP
- Live IP via [`gd32v_wifi`](https://github.com/klin-lang/gd32v_wifi)

## Usage

```klin
import "github/klin-lang/gd32v_wifi" wifi
import "github/klin-lang/gd32v_websocket" ws

fn main() {
    let mut e = wifi.sta_init()
    e = wifi.sta_connect("myssid", "mypass")
    e = wifi.sta_wait_ip(20000)
    if e != wifi.err_ok() {
        return
    }
    e = ws.connect("ws://echo.websocket.events/")
    let mut msg: [4]u8
    msg[0] = 112
    msg[1] = 105
    msg[2] = 110
    msg[3] = 103
    e = ws.send_text(cast(*u8, &msg[0]), 4)
    let mut out: [256]u8
    let mut n = ws.recv(cast(*mut u8, &out[0]), 256)
    let _d = ws.disconnect()
}
```

```sh
klin get github/klin-lang/gd32v_websocket@v0.1.0
```

Until publish, use this seed:

```sh
klin test patches/gd32v_websocket-v0.1.0/gd32v_websocket
klin run patches/gd32v_websocket-v0.1.0/examples/smoke/smoke.kl
```

## Links

- Klin issue: [161](https://github.com/klin-lang/klin/blob/main/issues/161-gd32v-websocket-sdk.md)
- Queue: [157](https://github.com/klin-lang/klin/blob/main/issues/157-later-tracks-gd32v-coap-ws-ibeacon-mesh-cloud.md) V3
- SDK example: `MSDK/examples/wifi/websocket_client` (tinyws)
