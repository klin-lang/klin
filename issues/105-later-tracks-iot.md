# 105 — Later tracks: IoT protocols / cloud edge

**Status:** 💭 backlog (ESP MQTT/OTA still open; VW553 MQTT ✅ [146](146-gd32v-mqtt-sdk.md); VW553 OTA ✅ [145](145-gd32v-ota-sdk.md); VW553 iBeacon 🔨 [158](158-gd32v-ble-ibeacon.md); VW553 CoAP 🔨 [160](160-gd32v-coap-sdk.md); VW553 WebSocket 🔨 [161](161-gd32v-websocket-sdk.md); Wi‑Fi Mesh/cloud staged → [157](157-later-tracks-gd32v-coap-ws-ibeacon-mesh-cloud.md))  
**Depends on:** [104](104-later-tracks-esp-network.md), [111](111-esp-sockets-idf.md), [112](112-esp-http-idf.md), [101](101-esp-wifi-idf.md), [102](102-esp-eth-idf.md), [145](145-gd32v-ota-sdk.md), [146](146-gd32v-mqtt-sdk.md), [157](157-later-tracks-gd32v-coap-ws-ibeacon-mesh-cloud.md), [158](158-gd32v-ble-ibeacon.md), [160](160-gd32v-coap-sdk.md), [161](161-gd32v-websocket-sdk.md)

## Verdict

Park **IoT-shaped** work above the thin network MVP (`esp_wifi` / `esp_eth`).  
This is a **maybe** queue: ship only when there is a concrete device + protocol need — not “IoT platform” scope creep.

Do **not** fold MQTT / cloud SDKs into `machine_*` or into the current STA/W5500 tags.  
Sockets ✅ [111](111-esp-sockets-idf.md); HTTP/TLS ✅ [112](112-esp-http-idf.md).  
VW553 OTA ✅ [145](145-gd32v-ota-sdk.md); VW553 MQTT client ✅ [146](146-gd32v-mqtt-sdk.md). ESP MQTT/OTA still open.

Sibling backlogs: [103](103-later-tracks-ble-usb-camera-lcd.md) (A–D MVP done; later tags), [106](106-esp-ble-idf.md) (BLE), [108](108-esp-usb-idf.md) (USB OTG), [109](109-esp-camera-idf.md) (camera), [110](110-board-waveshare-pico-lcd-114.md) (Pico LCD), [104](104-later-tracks-esp-network.md) (Wi‑Fi W1–W3 ✅; dual ✅; sockets ✅; HTTP/TLS ✅; RMII ✅).

## Prerequisites (not this issue)

| Need | Where |
|---|---|
| Link + IP (DHCP/static) | [101](101-esp-wifi-idf.md) / [102](102-esp-eth-idf.md) ✅ |
| TCP/UDP sockets | [111](111-esp-sockets-idf.md) / [104](104-later-tracks-esp-network.md) **N2** ✅ `@v0.1.0` |
| HTTP / TLS | [112](112-esp-http-idf.md) / [104](104-later-tracks-esp-network.md) **N3** ✅ `@v0.1.0` |

## Queue (piecemeal, optional)

| # | Track | Likely home | Notes |
|---|---|---|---|
| I1 | **MQTT** client | ESP: thin IDF package (open) / [`gd32v_mqtt`](https://github.com/klin-lang/gd32v_mqtt) [146](146-gd32v-mqtt-sdk.md) (VW553 ✅) | Publish/subscribe; buffers and client id **explicit**; no hidden reconnect heap in Klin. |
| I2 | **OTA** update | Thin IDF wrapper package (ESP) / [`gd32v_ota`](https://github.com/klin-lang/gd32v_ota) [145](145-gd32v-ota-sdk.md) (VW553) | Often uses HTTPS. Partition / URL / hash checks explicit; not board-pack magic. VW553 track started. |
| I3 | **CoAP** / **WebSocket** / **iBeacon** / **Wi‑Fi Mesh** / cloud | VW553: iBeacon 🔨 [158](158-gd32v-ble-ibeacon.md); CoAP 🔨 [160](160-gd32v-coap-sdk.md); WebSocket 🔨 [161](161-gd32v-websocket-sdk.md); Mesh/cloud staged [157](157-later-tracks-gd32v-coap-ws-ibeacon-mesh-cloud.md) | One stage at a time. ESP twins still optional later. |
| I4 | **Matter / Thread / Zigbee** | Far later | Heavy stacks; own decision when silicon + need exist — not MVP. |

## Rules

1. One track at a time; new issue when work starts.  
2. External repo preferred (compiler unchanged).  
3. Prime rule: no hidden allocation / control flow / cost.  
4. Credentials / broker URL / cert paths are **arguments** (or explicit files) — no baked-in cloud vendor.  
5. Prefer protocol clients over “IoT frameworks”.

## Out of scope (this issue)

- Implementation or picking a cloud vendor  
- HTTP client / TLS packaging — ✅ [112](112-esp-http-idf.md)  
- SoftAP provisioning UI (→ SoftAP API ✅ [104](104-later-tracks-esp-network.md) W1; UI/app later)  
- BLE mesh as “IoT” (→ [106](106-esp-ble-idf.md) / mesh later on that package; not this backlog)  
- Changing the Klin compiler  

## Links

- Network later: [104](104-later-tracks-esp-network.md)  
- Wi‑Fi / ETH MVP: [101](101-esp-wifi-idf.md), [102](102-esp-eth-idf.md)  
- Other later tracks: [103](103-later-tracks-ble-usb-camera-lcd.md)  
- VW553 CoAP / WS / iBeacon / Wi‑Fi Mesh / cloud: [157](157-later-tracks-gd32v-coap-ws-ibeacon-mesh-cloud.md) (CoAP → [160](160-gd32v-coap-sdk.md); WS → [161](161-gd32v-websocket-sdk.md))  
- BLE: [106](106-esp-ble-idf.md)  
- Targets: [062](062-targets-esp-rp.md)  
