# 102 — ESP Ethernet as a separate IDF package (`esp_eth`)

**Status:** ✅ published `@v0.1.2` (W5500 SPI) / [`@v0.2.0`](https://github.com/klin-lang/esp_eth/releases/tag/v0.2.0) (RMII EMAC, P4 first)  
**Depends on:** [021](021-c-libraries.md), [024](024-rtos.md), [049](049-remote-imports.md), [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md), [101](101-esp-wifi-idf.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | External: [`klin-lang/esp_eth`](https://github.com/klin-lang/esp_eth) `@v0.2.0` |
| Engine | **ESP-IDF** v5.x (`esp_eth` / netif / event loop) — not MMIO |
| Relation to `machine_esp` | **Separate.** Same class as [`esp_wifi`](https://github.com/klin-lang/esp_wifi) ([101](101-esp-wifi-idf.md)): IDF network stack, not `machine_*`. |
| One repo or many? | **One** `esp_eth` package for all backends (W5500 SPI + RMII now; other SPI later). Board packs supply pins only. |

## Silicon

| SoC | On-chip EMAC (RMII + PHY) | SPI ETH (W5500…) |
|---|---|---|
| ESP32 | yes (fixed RMII pads) | yes |
| ESP32-P4 | yes (IO_MUX data-plane set) | yes |
| ESP32-S3 / C3 | **no** (`rmii_start` → `ESP_ERR_NOT_SUPPORTED`) | yes |

## Scope (`@v0.2.0`)

- Backend: **W5500** SPI MAC+PHY (`w5500_start` with explicit SPI pins)  
- Backend: **RMII** internal EMAC (`rmii_start` — SMI / PHY / clock / data-plane pins explicit; P4 first)  
- PHY helpers: `phy_lan87xx()` / `phy_ip101()`; clock: `clk_ext_in()` / `clk_out()`  
- Shared: `wait_link` / `link_up` / `log_mac` / `wait_ip` / `ip_u32` / `gateway_u32` / `netmask_u32` / `log_ip` / `log_ip_info` / `stop`  
- Optional: `set_static_ip` + `ipv4` (DHCP off) / `set_hostname` — prefer before start  
- Implementation: `@[link("w5500_idf.c")]` + `@[cimport]` (both backends; shared `s_started`)  
- Examples: `examples/w5500_s3/` / `examples/rmii_p4/` (ESP-IDF v5.x, edit pins)  
- Changelog: `@v0.1.0` start+wait_ip → `@v0.1.1` link/MAC → `@v0.1.2` static IP / hostname / gw+mask → `@v0.2.0` RMII  
- `version()` → `4`

## Out of scope (this tag)

- Other SPI chips (DM9051 / KSZ8851 / ENC28J60) — later → [104](104-later-tracks-esp-network.md) **E2/E3**  
- Dual Wi‑Fi+ETH prefer/failover ✅ [113](113-esp-netif-dual-idf.md); sockets ✅ [111](111-esp-sockets-idf.md); HTTP ✅ [112](112-esp-http-idf.md)  
- Freestanding (no IDF)  
- Folding into `machine_esp` or board pack APIs  
- Classic ESP32 as a first-class host example (same `rmii_start` API; P4 example ships first)

## Contract (prime rule)

- SPI host / MOSI / MISO / SCLK / CS / INT / RST / clock are **arguments** (no hidden pin map).  
- RMII MDC / MDIO / RST / PHY addr / PHY kind / clock mode / clock GPIO / data-plane pads are **arguments**.  
- IDF netif / DHCP (or static IP) / event loop are IDF contracts.  
- Errors are `i32` (`esp_err_t`).

## Usage — W5500 (DHCP)

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

## Usage — RMII on ESP32-P4 (DHCP)

Pins below are IDF P4 defaults / **ESP32-P4-Function-EV-Board** (IP101).
Change `phy_kind` / addr / reset for a LAN8720 DIY board.

```klin
import "github/klin-lang/esp_eth" eth

@[cexport, codename("klin_app_main")]
fn app() {
  let mut e = eth.rmii_start(
    31, 52,           // MDC MDIO
    51,               // PHY RST (−1 = unused)
    1,                // PHY addr
    eth.phy_ip101(),  // or eth.phy_lan87xx()
    eth.clk_ext_in(), // external 50 MHz REF_CLK
    50,               // clock GPIO
    -1,               // clock_in loopback (clk_out only)
    49, 34, 35,       // TX_EN TXD0 TXD1
    28, 29, 30        // CRS_DV RXD0 RXD1
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
  let mut e = eth.rmii_start(
    31, 52, 51, 1, eth.phy_ip101(),
    eth.clk_ext_in(), 50, -1,
    49, 34, 35, 28, 29, 30
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
klin get github/klin-lang/esp_eth@v0.2.0
```

## Links

- Repo: https://github.com/klin-lang/esp_eth  
- Tags: [v0.1.2](https://github.com/klin-lang/esp_eth/releases/tag/v0.1.2), [v0.2.0](https://github.com/klin-lang/esp_eth/releases/tag/v0.2.0)  
- Wi‑Fi sibling: [101](101-esp-wifi-idf.md) / [`esp_wifi`](https://github.com/klin-lang/esp_wifi)  
- Dual Wi‑Fi+ETH glue: [113](113-esp-netif-dual-idf.md) / [`esp_netif_dual`](https://github.com/klin-lang/esp_netif_dual)  
- BLE sibling: [106](106-esp-ble-idf.md) / [`esp_ble`](https://github.com/klin-lang/esp_ble)  
- Network later backlog: [104](104-later-tracks-esp-network.md) (E2+ SPI chips)  
- Chip MMIO: [099](099-machine-esp-esp32-s3.md) / [114](114-machine-esp-esp32-p4.md) / [`machine_esp`](https://github.com/klin-lang/machine_esp)  
- Catalog: [061](061-micropython-machine-api.md), targets [062](062-targets-esp-rp.md)  
