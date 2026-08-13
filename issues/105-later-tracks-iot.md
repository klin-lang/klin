# 105 — Later tracks: IoT protocols / cloud edge

**Status:** 💭 backlog (**maybe** — not committed; do **one track at a time** if started)  
**Depends on:** [104](104-later-tracks-esp-network.md) (sockets **and** HTTP/TLS first), [101](101-esp-wifi-idf.md), [102](102-esp-eth-idf.md)

## Verdict

Park **IoT-shaped** work above the thin network MVP (`esp_wifi` / `esp_eth`).  
This is a **maybe** queue: ship only when there is a concrete device + protocol need — not “IoT platform” scope creep.

Do **not** fold MQTT / cloud SDKs into `machine_*` or into the current STA/W5500 tags.  
Do **not** start here before thin **sockets** ([104](104-later-tracks-esp-network.md) N2) **and** **HTTP/TLS** ([104](104-later-tracks-esp-network.md) N3).

Sibling backlogs: [103](103-later-tracks-ble-usb-camera-lcd.md) (USB / camera / LCD), [106](106-esp-ble-idf.md) (BLE), [104](104-later-tracks-esp-network.md) (SoftAP / RMII / sockets / HTTP/TLS…).

## Prerequisites (not this issue)

| Need | Where |
|---|---|
| Link + IP (DHCP/static) | [101](101-esp-wifi-idf.md) / [102](102-esp-eth-idf.md) ✅ |
| TCP/UDP sockets | [104](104-later-tracks-esp-network.md) **N2** — later |
| HTTP / TLS | [104](104-later-tracks-esp-network.md) **N3** — later (stays in 104; not re-queued here) |

## Queue (piecemeal, optional)

| # | Track | Likely home | Notes |
|---|---|---|---|
| I1 | **MQTT** client | Separate package (e.g. thin FFI over ESP-IDF `mqtt` / eclipse-paho-style C) | Needs sockets + TLS from [104](104-later-tracks-esp-network.md). Publish/subscribe; buffers and client id **explicit**; no hidden reconnect heap in Klin. |
| I2 | **OTA** update | Thin IDF wrapper package | Often uses HTTPS from [104](104-later-tracks-esp-network.md) N3. Partition / URL / hash checks explicit; not board-pack magic. |
| I3 | **CoAP** | Later / low priority | Only if a desk project needs it. |
| I4 | **Matter / Thread / Zigbee** | Far later | Heavy stacks; own decision when silicon + need exist — not MVP. |

## Rules

1. One track at a time; new issue when work starts.  
2. External repo preferred (compiler unchanged).  
3. Prime rule: no hidden allocation / control flow / cost.  
4. Credentials / broker URL / cert paths are **arguments** (or explicit files) — no baked-in cloud vendor.  
5. Prefer protocol clients over “IoT frameworks”.

## Out of scope (this issue)

- Implementation or picking a cloud vendor  
- HTTP client / TLS packaging (→ [104](104-later-tracks-esp-network.md) N3)  
- SoftAP provisioning UI (→ [104](104-later-tracks-esp-network.md) W1 first)  
- BLE mesh as “IoT” (→ [106](106-esp-ble-idf.md) / bonding+mesh later on that package; not this backlog)  
- Changing the Klin compiler  

## Links

- Network later: [104](104-later-tracks-esp-network.md)  
- Wi‑Fi / ETH MVP: [101](101-esp-wifi-idf.md), [102](102-esp-eth-idf.md)  
- Other later tracks: [103](103-later-tracks-ble-usb-camera-lcd.md)  
- BLE: [106](106-esp-ble-idf.md)  
- Targets: [062](062-targets-esp-rp.md)  
