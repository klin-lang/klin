# 111 — ESP LwIP sockets as a separate IDF package (`esp_sockets`)

**Status:** ✅ published `@v0.1.0` (TCP/UDP BSD thin surface)  
**Depends on:** [021](021-c-libraries.md), [024](024-rtos.md), [049](049-remote-imports.md), [101](101-esp-wifi-idf.md) / [102](102-esp-eth-idf.md) (netif + IP first), [104](104-later-tracks-esp-network.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | External: [`klin-lang/esp_sockets`](https://github.com/klin-lang/esp_sockets) `@v0.1.0` |
| Engine | **ESP-IDF** LwIP BSD sockets (`lwip/sockets.h`, `getaddrinfo`) |
| Relation to `esp_wifi` / `esp_eth` | **Separate.** Those packages own link + IP. This package is only sockets **after** a netif has an address. |
| Relation to `machine_esp` | **Separate.** Not MMIO. |

Track **N2** from [104](104-later-tracks-esp-network.md).

## Why not fold into `esp_wifi`?

Sockets sit **above** Wi‑Fi and Ethernet. Folding TCP into `esp_wifi` would hide the split and block ETH-only apps. Pattern matches [104] rule 3: sockets / HTTP / TLS = **new** packages.

## Scope (`@v0.1.0`)

- `tcp` / `udp` — create → fd ≥ 0 or `-1`  
- `connect_ipv4` / `connect_host` — TCP connect (lwIP `u32` IP / DNS via `getaddrinfo`)  
- `bind` / `listen` / `accept` — server side  
- `send` / `recv` / `sendto` / `recvfrom` — **caller buffers**  
- `close` / `set_recv_timeout_ms`  
- `ipv4` / `err_ok` / `version()` → `1`  
- Implementation: `@[link("sock_idf.c")]` + `@[cimport]`  
- Smoke: `examples/smoke/`; hardware sketch: `examples/tcp_client/` (netif must already be up)

## Out of scope

- Bringing up Wi‑Fi / ETH / DHCP (→ [101](101-esp-wifi-idf.md) / [102](102-esp-eth-idf.md))  
- HTTP / TLS (→ [104](104-later-tracks-esp-network.md) **N3**)  
- MQTT / OTA (→ [105](105-later-tracks-iot.md); after N3)  
- IPv6 / non-blocking select/poll MVP  
- Changing the Klin compiler  

## Contract (prime rule)

- No Klin GC / hidden heap — payloads are buffers you pass.  
- DNS (`connect_host`) and LwIP socket tables are **IDF contracts**.  
- Create/accept: `-1` on failure; connect/bind/listen/close: `0` / `-1`; send/recv: byte count or `-1` (recv `0` = peer closed).  

## Usage (TCP client — after Wi‑Fi IP)

```klin
import "github/klin-lang/esp_sockets" sock

@[cexport, codename("klin_app_main")]
fn app() {
  // … wifi.sta_wait_ip … first …
  let fd = sock.tcp()
  if fd < 0 {
    return
  }
  let e = sock.connect_ipv4(fd, sock.ipv4(192, 168, 1, 10), 8080)
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
klin get github/klin-lang/esp_sockets@v0.1.0
```

## Links

- Repo: https://github.com/klin-lang/esp_sockets  
- Tag: [v0.1.0](https://github.com/klin-lang/esp_sockets/releases/tag/v0.1.0)  
- Network later: [104](104-later-tracks-esp-network.md)  
- Wi‑Fi / ETH: [101](101-esp-wifi-idf.md), [102](102-esp-eth-idf.md)  
- IoT later: [105](105-later-tracks-iot.md)  
