# 105 — Later tracks: IoT protocols / cloud edge

**Status:** 💭 backlog (**maybe** — not committed; do **one track at a time** if started)  
**Depends on:** [104](104-later-tracks-esp-network.md) (sockets / TLS first), [101](101-esp-wifi-idf.md), [102](102-esp-eth-idf.md)

## Verdict

Park **IoT-shaped** work above the thin network MVP (`esp_wifi` / `esp_eth`).  
This is a **maybe** queue: ship only when there is a concrete device + protocol need — not “IoT platform” scope creep.

Do **not** fold MQTT / cloud SDKs into `machine_*` or into the current STA/W5500 tags.  
Do **not** start here before a thin sockets (and usually TLS) package from [104](104-later-tracks-esp-network.md).

Sibling backlogs: [103](103-later-tracks-ble-usb-camera-lcd.md) (BLE / USB / camera / LCD), [104](104-later-tracks-esp-network.md) (SoftAP / RMII / sockets…).

## Prerequisites (not this issue)

| Need | Where |
|---|---|
| Link + IP (DHCP/static) | [101](101-esp-wifi-idf.md) / [102](102-esp-eth-idf.md) ✅ |
| TCP/UDP sockets | [104](104-later-tracks-esp-network.md) N2 — later |
| TLS | [104](104-later-tracks-esp-network.md) N3 — later |

## Queue (piecemeal, optional)

| # | Track | Likely home | Notes |
|---|---|---|---|
| I1 | **MQTT** client | Separate package (e.g. thin FFI over ESP-IDF `mqtt` / eclipse-paho-style C) | Publish/subscribe; buffers and client id **explicit**; no hidden reconnect heap in Klin. |
| I2 | **HTTP client** (REST) | Separate package or share with [104](104-later-tracks-esp-network.md) N3 | GET/POST over TLS; response buffer caller-owned. |
| I3 | **OTA** update | Thin IDF wrapper package | Partition / URL / hash checks explicit; not board-pack magic. |
| I4 | **CoAP** | Later / low priority | Only if a desk project needs it. |
| I5 | **Matter / Thread / Zigbee** | Far later | Heavy stacks; own decision when silicon + need exist — not MVP. |

## Rules

1. One track at a time; new issue when work starts.  
2. External repo preferred (compiler unchanged).  
3. Prime rule: no hidden allocation / control flow / cost.  
4. Credentials / broker URL / cert paths are **arguments** (or explicit files) — no baked-in cloud vendor.  
5. Prefer protocol clients over “IoT frameworks”.

## Out of scope (this issue)

- Implementation or picking a cloud vendor  
- SoftAP provisioning UI (→ [104](104-later-tracks-esp-network.md) W1 first)  
- BLE mesh as “IoT” (→ [103](103-later-tracks-ble-usb-camera-lcd.md))  
- Changing the Klin compiler  

## Links

- Network later: [104](104-later-tracks-esp-network.md)  
- Wi‑Fi / ETH MVP: [101](101-esp-wifi-idf.md), [102](102-esp-eth-idf.md)  
- Other later tracks: [103](103-later-tracks-ble-usb-camera-lcd.md)  
- Targets: [062](062-targets-esp-rp.md)  
