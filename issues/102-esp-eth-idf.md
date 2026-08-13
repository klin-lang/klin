# 102 — ESP Ethernet as a separate IDF package (`esp_eth`)

**Status:** ✅ published `@v0.1.2` (W5500 SPI + link/MAC + static IP)  
**Depends on:** [021](021-c-libraries.md), [024](024-rtos.md), [049](049-remote-imports.md), [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md), [101](101-esp-wifi-idf.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | External: [`klin-lang/esp_eth`](https://github.com/klin-lang/esp_eth) `@v0.1.2` |
| Engine | **ESP-IDF** v5.x (`esp_eth` / netif / event loop) — not MMIO |
| Relation to `machine_esp` | **Separate.** Same class as [`esp_wifi`](https://github.com/klin-lang/esp_wifi) ([101](101-esp-wifi-idf.md)): IDF network stack, not `machine_*`. |
| One repo or many? | **One** `esp_eth` package for all backends (W5500 SPI now; RMII later). Board packs supply pins only. |

## Silicon

| SoC | On-chip EMAC (RMII + PHY) | SPI ETH (W5500…) |
|---|---|---|
| ESP32 | yes | yes |
| ESP32-P4 | yes | yes |
| ESP32-S3 / C3 | **no** | yes |

## Scope (`@v0.1.2`)

- Backend: **W5500** SPI MAC+PHY (`w5500_start` with explicit SPI pins)  
- Shared: `wait_link` / `link_up` / `log_mac` / `wait_ip` / `ip_u32` / `gateway_u32` / `netmask_u32` / `log_ip` / `log_ip_info` / `stop`  
- Optional: `set_static_ip` + `ipv4` (DHCP off) / `set_hostname` — prefer before start  
- Implementation: `@[link("w5500_idf.c")]` + `@[cimport]`  
- Example: `examples/w5500_s3/` (ESP-IDF v5.x, edit pins)  
- Changelog: `@v0.1.0` start+wait_ip → `@v0.1.1` link/MAC → `@v0.1.2` static IP / hostname / gw+mask

## Out of scope (this tag)

- RMII / other SPI chips / sockets / HTTP / TLS / dual Wi‑Fi+ETH — later → [104](104-later-tracks-esp-network.md) (same `esp_eth` package for RMII + SPI backends; **P4 preferred first RMII** host — see [062](062-targets-esp-rp.md))  
- Freestanding (no IDF)  
- Folding into `machine_esp` or board pack APIs

## Contract (prime rule)

- SPI host / MOSI / MISO / SCLK / CS / INT / RST / clock are **arguments** (no hidden pin map).  
- IDF netif / DHCP (or static IP) / event loop are IDF contracts.  
- Errors are `i32` (`esp_err_t`).

## Usage (DHCP)

```klin
import "github/klin-lang/esp_eth" eth

@[cexport, codename("klin_app_main")]
fn app() {
  let mut e = eth.w5500_start(
    eth.spi2_host(),
    11, 13, 12, 14, // MOSI MISO SCLK CS — board-specific
    10, 9,          // INT RST (−1 if unused / poll)
    20, 10          // MHz, poll_ms
  )
  if e != eth.err_ok() {
    return
  }
  eth.log_mac()
  e = eth.wait_link(15000)
  if e != eth.err_ok() {
    return
  }
  e = eth.wait_ip(30000)
  if e != eth.err_ok() {
    return
  }
  eth.log_ip_info()
}
```

## Usage (static IP)

```klin
import "github/klin-lang/esp_eth" eth

@[cexport, codename("klin_app_main")]
fn app() {
  let _h = eth.set_hostname("klin-eth")
  let _s = eth.set_static_ip(
    eth.ipv4(192, 168, 1, 50),
    eth.ipv4(192, 168, 1, 1),
    eth.ipv4(255, 255, 255, 0)
  )
  let mut e = eth.w5500_start(
    eth.spi2_host(),
    11, 13, 12, 14,
    10, 9, 20, 10
  )
  if e != eth.err_ok() {
    return
  }
  e = eth.wait_link(15000)
  if e != eth.err_ok() {
    return
  }
  e = eth.wait_ip(5000)
  if e != eth.err_ok() {
    return
  }
  eth.log_ip_info()
}
```

```sh
klin get github/klin-lang/esp_eth@v0.1.2
```

## Links

- Repo: https://github.com/klin-lang/esp_eth  
- Tag: [v0.1.2](https://github.com/klin-lang/esp_eth/releases/tag/v0.1.2)  
- Wi‑Fi sibling: [101](101-esp-wifi-idf.md) / [`esp_wifi`](https://github.com/klin-lang/esp_wifi)  
- Network later backlog: [104](104-later-tracks-esp-network.md)  
- Chip MMIO: [099](099-machine-esp-esp32-s3.md) / [`machine_esp`](https://github.com/klin-lang/machine_esp)  
- Catalog: [061](061-micropython-machine-api.md), targets [062](062-targets-esp-rp.md)  
