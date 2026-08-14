# 113 — ESP dual Wi‑Fi+ETH glue (`esp_netif_dual`)

**Status:** ✅ published `@v0.1.0` (prefer ETH / poll failover / route metrics)  
**Depends on:** [021](021-c-libraries.md), [024](024-rtos.md), [049](049-remote-imports.md), [101](101-esp-wifi-idf.md), [102](102-esp-eth-idf.md), [104](104-later-tracks-esp-network.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | External: [`klin-lang/esp_netif_dual`](https://github.com/klin-lang/esp_netif_dual) `@v0.1.0` |
| Engine | **ESP-IDF** `esp_netif` (`set_default_netif`, route prio, ifkey lookup) |
| Relation to `esp_wifi` / `esp_eth` | **Glue above both.** Those create netifs + DHCP. This package only picks the **default route**. |
| Bonding / LACP? | **Out of scope** this tag |

Track **N1** from [104](104-later-tracks-esp-network.md).

## Why a new package?

Two netifs already DHCP independently. What was missing was an explicit Klin API for “prefer ETH”, poll failover, and route metrics — without folding that into either link package or adding hidden event handlers.

## Scope (`@v0.1.0`)

- Lookup IDF ifkeys `WIFI_STA_DEF` / `ETH_DEF` (defaults from `esp_wifi` STA + `esp_eth`)  
- `wifi_present` / `eth_present` / `wifi_up` / `eth_up` / `wifi_has_ip` / `eth_has_ip`  
- `prefer_wifi` / `prefer_eth` — `esp_netif_set_default_netif`  
- `apply_prefer_eth` — **poll**: ETH if has IP, else Wi‑Fi if has IP (no GOT_IP handlers)  
- `default_is_wifi` / `default_is_eth` / `last_choice`  
- `wifi_route_prio` / `eth_route_prio` (read); `set_*_route_prio` (IDF ≥ 5.5, else `ESP_ERR_NOT_SUPPORTED`)  
- `version()` → `1`  
- Implementation: `@[link("dual_idf.c")]` + `@[cimport]`  
- Smoke: `examples/smoke/`; sketch: `examples/prefer_eth/`

## Out of scope

- Bringing up Wi‑Fi / ETH / DHCP  
- Bonding / LACP / SoftAP+ETH / APSTA  
- Hidden background failover task or event handlers  
- Changing the Klin compiler  

## Contract (prime rule)

- No hidden control flow — failover is `apply_prefer_eth` you call.  
- No link bring-up — cost stays in `esp_wifi` / `esp_eth`.  
- Errors are `i32` (`esp_err_t`).

## Usage

```klin
import "github/klin-lang/esp_netif_dual" dual

@[cexport, codename("klin_app_main")]
fn app() {
  // … wifi.sta_wait_ip … and eth.wait_ip … first …
  let mut e = dual.apply_prefer_eth()
  if e != dual.err_ok() {
    return
  }
  // poll later when link may drop:
  e = dual.apply_prefer_eth()
}
```

```sh
klin get github/klin-lang/esp_netif_dual@v0.1.0
```

## Links

- Repo: https://github.com/klin-lang/esp_netif_dual  
- Tag: [v0.1.0](https://github.com/klin-lang/esp_netif_dual/releases/tag/v0.1.0)  
- Network later: [104](104-later-tracks-esp-network.md)  
- Wi‑Fi / ETH: [101](101-esp-wifi-idf.md), [102](102-esp-eth-idf.md)  
