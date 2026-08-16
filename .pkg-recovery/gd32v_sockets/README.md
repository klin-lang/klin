# gd32v_sockets

Thin **GD32VW55x LwIP BSD sockets** (TCP/UDP) for [Klin](https://github.com/klin-lang/klin).

**Does not** bring up Wi‑Fi — get an IP first with
[`gd32v_wifi`](https://github.com/klin-lang/gd32v_wifi). Same split as ESP
[`esp_sockets`](https://github.com/klin-lang/esp_sockets) vs `esp_wifi`
(Klin [111](https://github.com/klin-lang/klin/blob/main/issues/111-esp-sockets-idf.md) /
[143](https://github.com/klin-lang/klin/blob/main/issues/143-gd32v-sockets-sdk.md)).

C engine = LwIP sockets (`lwip/sockets.h`, `getaddrinfo` from the GigaDevice
VW55x SDK). Klin is a thin FFI client (`@[link("sock_sdk.c")]` + `@[cimport]`).
All payloads are **caller buffers**. DNS via `connect_host` is an **LwIP/SDK
cost**, not Klin magic.

**Not** [`esp_sockets`](https://github.com/klin-lang/esp_sockets) — that is ESP-IDF.

## Status (`@v0.1.0`)

| API | Notes |
|---|---|
| `tcp` / `udp` | Create socket → fd ≥ 0 or `-1` |
| `connect_ipv4` / `connect_host` | TCP connect (IP lwIP order / DNS) |
| `bind` / `listen` / `accept` | Server side |
| `send` / `recv` | TCP or connected; caller buffer |
| `sendto` / `recvfrom` | UDP; `out_ip` / `out_port` optional pointers |
| `close` / `set_recv_timeout_ms` | Thin |
| `ipv4` / `err_ok` / `version` | Helpers (`version()` → `1`) |

HTTP / TLS → [`gd32v_http`](https://github.com/klin-lang/gd32v_http).

## Requirements

- [Klin](https://github.com/klin-lang/klin) compiler
- [GD32VW55x_WiFi_BLE_SDK](https://github.com/GigaDeviceSemiconductor/GD32VW55x_WiFi_BLE_SDK) with LwIP
- Live STA/SoftAP IP via [`gd32v_wifi`](https://github.com/klin-lang/gd32v_wifi) before connect/bind

## Usage (TCP client — after Wi‑Fi IP)

```klin
import "github/klin-lang/gd32v_wifi" wifi
import "github/klin-lang/gd32v_sockets" sock

fn main() {
    let mut e = wifi.sta_init()
    e = wifi.sta_connect("myssid", "mypass")
    e = wifi.sta_wait_ip(20000)
    if e != wifi.err_ok() {
        return
    }
    let fd = sock.tcp()
    if fd < 0 {
        return
    }
    e = sock.connect_ipv4(fd, sock.ipv4(192, 168, 1, 10), 8080)
    if e != sock.err_ok() {
        let _c = sock.close(fd)
        return
    }
    let mut hi: [5]u8
    hi[0] = 104
    hi[1] = 101
    hi[2] = 108
    hi[3] = 108
    hi[4] = 111
    let _n = sock.send(fd, cast(*u8, &hi[0]), 5)
    let mut buf: [64]u8
    let _r = sock.recv(fd, cast(*mut u8, &buf[0]), 64)
    let _x = sock.close(fd)
}
```

```sh
klin get github/klin-lang/gd32v_sockets@v0.1.0
```

## Contract (prime rule)

- No Klin GC / hidden heap — `send`/`recv` buffers are yours.
- Socket FDs are LwIP integers; close them explicitly.
- Errors: create/accept → `-1`; connect/bind/listen/close → `0` / `-1`;
  send/recv → byte count or `-1` (recv `0` = peer closed).
- Does not configure Wi‑Fi, DHCP, or TLS.

## Tests

```sh
dart run /path/to/klin/bin/klin.dart test gd32v_sockets/
```

Host `klin test` uses stubs when `lwip/sockets.h` is not on the include path.

## Changelog

| Tag | Notes |
|---|---|
| `@v0.1.0` | TCP/UDP BSD thin surface |
