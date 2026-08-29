# gd32v_coap

Thin **GD32VW55x CoAP (RFC 7252) client** for [Klin](https://github.com/klin-lang/klin).

**Client only** — not a server. **Does not** bring up Wi‑Fi — get an IP first
with [`gd32v_wifi`](https://github.com/klin-lang/gd32v_wifi). Sibling of
[`gd32v_sockets`](https://github.com/klin-lang/gd32v_sockets) /
[`gd32v_http`](https://github.com/klin-lang/gd32v_http).

C engine = minimal CoAP encode/decode over **LwIP UDP** (when
`lwip/sockets.h` is on the include path). Klin is a thin FFI client
(`@[link("coap_sdk.c")]` + `@[cimport]`). Payloads are **caller buffers**.
Confirmable (CON) vs non-confirmable (NON) is an **explicit** `confirm`
argument.

Not a libcoap FFI wrapper (SDK ships libcoap for its own demos; this package
stays a fixed-size UDP client). Not ESP-IDF.

## Status (`@v0.1.0`)

| API | Notes |
|---|---|
| `get` / `put` | URI `coap://host[:port]/path`; payload → caller buffer |
| `confirm_yes` / `confirm_no` | `1` = CON, `0` = NON |
| `last_code` | Last response code (e.g. `69` = 2.05 Content) |
| `err_ok` / `version` | Helpers (`version()` → `1`) |

## Requirements

- [Klin](https://github.com/klin-lang/klin) compiler
- LwIP sockets (GD32VW55x Wi‑Fi BLE SDK) for on-device UDP
- Live IP via [`gd32v_wifi`](https://github.com/klin-lang/gd32v_wifi)

## Usage

```klin
import "github/klin-lang/gd32v_wifi" wifi
import "github/klin-lang/gd32v_coap" coap

fn main() {
    let mut e = wifi.sta_init()
    e = wifi.sta_connect("myssid", "mypass")
    e = wifi.sta_wait_ip(20000)
    if e != wifi.err_ok() {
        return
    }
    let mut out: [256]u8
    let mut n = coap.get(
        "coap://californium.eclipseprojects.io/validate",
        cast(*mut u8, &out[0]),
        256,
        coap.confirm_yes()
    )
}
```

```sh
klin get github/klin-lang/gd32v_coap@v0.1.0
```

Until publish, use this seed:

```sh
klin test patches/gd32v_coap-v0.1.0/gd32v_coap
klin run -I patches/gd32v_coap-v0.1.0 \
  patches/gd32v_coap-v0.1.0/examples/smoke/smoke.kl
```

## Host tests

```sh
klin test gd32v_coap
```

## Links

- Klin issue: [159](https://github.com/klin-lang/klin/blob/main/issues/160-gd32v-coap-sdk.md)
- Queue: [157](https://github.com/klin-lang/klin/blob/main/issues/157-later-tracks-gd32v-coap-ws-ibeacon-mesh-cloud.md) V2
- SDK example: `MSDK/examples/wifi/coap` (libcoap)
