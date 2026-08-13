# 104 — Later tracks: ESP network (`esp_wifi` / `esp_eth` beyond MVP)

**Status:** 💭 backlog (do **one track at a time**; not the current step)  
**Depends on:** [101](101-esp-wifi-idf.md), [102](102-esp-eth-idf.md), [062](062-targets-esp-rp.md)

## Verdict

Parked follow-ups after the thin STA / W5500 MVP.  
**DHCP (dynamic IP) stays the default** on both packages; optional static IP is additive on newer package tags (see package READMEs / releases — Klin issue text in [101](101-esp-wifi-idf.md) / [102](102-esp-eth-idf.md) may lag).  
Do **not** expand the “current tag” scope of those issues with the rows below — pick one, ship a small additive tag or sibling package, then the next.

Sibling backlog (non-network): [103](103-later-tracks-ble-usb-camera-lcd.md) (USB OTG / camera / Pico LCD); BLE MVP → [106](106-esp-ble-idf.md).

## Done (context)

| Track | Where |
|---|---|
| Wi‑Fi STA (IDF; DHCP default) | [`esp_wifi`](https://github.com/klin-lang/esp_wifi) → [101](101-esp-wifi-idf.md) |
| ETH W5500 SPI (IDF; DHCP default) | [`esp_eth`](https://github.com/klin-lang/esp_eth) → [102](102-esp-eth-idf.md) |

## Queue — Wi‑Fi (`esp_wifi` or sibling)

| # | Track | Likely home | Notes |
|---|---|---|---|
| W1 | **SoftAP** | Same `esp_wifi` package (additive) or thin sibling | Explicit AP SSID/pass/channel; not hidden “provisioning magic”. |
| W2 | **Scan** (SSID list) | `esp_wifi` | Caller-visible buffer / count; no hidden heap in Klin. |
| W3 | **RSSI / link stats** | `esp_wifi` | Thin ioctl/query after assoc. |

## Queue — Ethernet (`esp_eth`, same package)

| # | Track | Likely home | Notes |
|---|---|---|---|
| E1 | **RMII internal EMAC** | `esp_eth` | SoCs with on-chip EMAC: classic **ESP32**; prefer **ESP32-P4** when that port is on the desk (targets [062](062-targets-esp-rp.md) — P4 may still be “Later” there). PHY e.g. LAN8720 / IP101; pins / PHY args explicit. |
| E2 | **Other SPI MAC+PHY** | `esp_eth` | **DM9051**, **KSZ8851SNL** (IDF-native); same pattern as `w5500_start`. |
| E3 | **ENC28J60** | `esp_eth` (low priority) | IDF-discouraged for new designs; only if hardware on the desk. |
| E4 | **CH390 / esp-eth-drivers** | later | Outside core IDF; optional after E2. |

## Queue — shared / above both packages

| # | Track | Likely home | Notes |
|---|---|---|---|
| N1 | **Dual Wi‑Fi + ETH** | New thin glue or app-level | Two `esp_netif`s can already DHCP independently. **No** Klin API yet for bonding, failover, “prefer ETH”, or route metrics. |
| N2 | **LwIP sockets** | Separate package (not folded into `esp_wifi`/`esp_eth` MVP) | TCP/UDP thin FFI; prime rule: buffers explicit. |
| N3 | **HTTP / TLS** | Separate package(s) | After sockets; no hidden cert store / allocator. |

## Optional micro-helpers (only with hardware need)

Parked; do not ship “for completeness”:

- DNS server `u32` getters  
- `set_mac` / custom MAC  
- Reconnect policy knobs beyond the documented small retry  

## Rules

1. One track at a time; new issue slice when work starts if the row grows large.  
2. Prefer additive tags on existing repos (`esp_wifi` / `esp_eth`) for SoftAP / RMII / SPI backends.  
3. Sockets / HTTP / TLS = **new** packages (like `esp_wifi` vs `machine_esp`).  
4. Prime rule: no hidden allocation / control flow / cost.  
5. Classic ESP32 / P4 `machine_*` ports stay under [062](062-targets-esp-rp.md) — RMII in `esp_eth` can land when that silicon is on the desk (does not require a finished `machine_esp` P4 port).

## Out of scope (this issue)

- Implementation  
- BLE (→ [106](106-esp-ble-idf.md); remaining tracks in [103](103-later-tracks-ble-usb-camera-lcd.md))  
- IoT protocols / MQTT / OTA (→ [105](105-later-tracks-iot.md); after sockets/TLS here)  
- Changing the Klin compiler  

## Links

- Wi‑Fi: [101](101-esp-wifi-idf.md) / https://github.com/klin-lang/esp_wifi  
- Ethernet: [102](102-esp-eth-idf.md) / https://github.com/klin-lang/esp_eth  
- Other later tracks: [103](103-later-tracks-ble-usb-camera-lcd.md)  
- BLE MVP: [106](106-esp-ble-idf.md)  
- IoT later (maybe): [105](105-later-tracks-iot.md)  
- Targets: [062](062-targets-esp-rp.md)  
