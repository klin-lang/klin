# 143 — GD32VW553 LwIP sockets as a separate SDK package (`gd32v_sockets`)

**Status:** ✅ [`gd32v_sockets@v0.1.0`](https://github.com/klin-lang/gd32v_sockets/releases/tag/v0.1.0) published (TCP/UDP BSD; host `klin test` PASS)  
**Depends on:** [021](021-c-libraries.md), [024](024-rtos.md), [049](049-remote-imports.md), [137](137-gd32v-wifi-sdk.md) (IP first), [062](062-targets-esp-rp.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | External: [`klin-lang/gd32v_sockets`](https://github.com/klin-lang/gd32v_sockets) `@v0.1.0` |
| Engine | **GigaDevice VW55x LwIP** BSD sockets (`lwip/sockets.h`, `getaddrinfo`) — not MMIO, **not** ESP-IDF |
| Relation to `gd32v_wifi` | **Separate.** Wi‑Fi owns link + IP. This package is only sockets **after** a vif has an address. |
| Relation to `machine_gd32v` | **Separate.** Not MMIO. |
| ESP twin | [`esp_sockets`](https://github.com/klin-lang/esp_sockets) [111](111-esp-sockets-idf.md) |

## Why not fold into `gd32v_wifi`?

Sockets sit **above** Wi‑Fi. Folding TCP into `gd32v_wifi` would hide the split and block SoftAP-only / future non-Wi‑Fi IP paths. Same rule as ESP [104](104-later-tracks-esp-network.md) / [111](111-esp-sockets-idf.md): sockets / HTTP / TLS = **new** packages.

## Scope (`@v0.1.0`)

- `tcp` / `udp` — create → fd ≥ 0 or `-1`  
- `connect_ipv4` / `connect_host` — TCP connect (lwIP `u32` IP / DNS via `getaddrinfo`)  
- `bind` / `listen` / `accept` — server side  
- `send` / `recv` / `sendto` / `recvfrom` — **caller buffers**  
- `close` / `set_recv_timeout_ms`  
- `ipv4` / `err_ok` / `version()` → `1`  
- Implementation: `@[link("sock_sdk.c")]` + `@[cimport]` (`klin_gd32v_sock_*`)  
- Host `klin test` stubs when `lwip/sockets.h` is absent  
- Smoke: `examples/smoke/`; sketch: `examples/tcp_client/` (IP must already be up)

## Out of scope

- Bringing up Wi‑Fi / DHCP (→ [137](137-gd32v-wifi-sdk.md))  
- HTTP / TLS — [144](144-gd32v-http-sdk.md)  
- MQTT / OTA — OTA → [145](145-gd32v-ota-sdk.md); MQTT still [105](105-later-tracks-iot.md)  
- IPv6 / non-blocking select/poll MVP  
- Changing the Klin compiler  
- Using [`esp_sockets`](https://github.com/klin-lang/esp_sockets) on VW553 (wrong engine)

## Contract (prime rule)

- No Klin GC / hidden heap — payloads are buffers you pass.  
- DNS (`connect_host`) and LwIP socket tables are **SDK contracts**.  
- Create/accept: `-1` on failure; connect/bind/listen/close: `0` / `-1`; send/recv: byte count or `-1` (recv `0` = peer closed).  

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
    let _x = sock.close(fd)
}
```

```sh
klin get github/klin-lang/gd32v_sockets@v0.1.0
```

## Links

- Repo: https://github.com/klin-lang/gd32v_sockets  
- Tag: [v0.1.0](https://github.com/klin-lang/gd32v_sockets/releases/tag/v0.1.0)  
- Wi‑Fi: [137](137-gd32v-wifi-sdk.md)  
- HTTP: [144](144-gd32v-http-sdk.md)  
- ESP twin: [111](111-esp-sockets-idf.md)  
