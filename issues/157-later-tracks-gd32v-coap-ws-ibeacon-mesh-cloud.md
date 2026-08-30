# 157 — Later tracks: GD32VW553 CoAP / WebSocket / iBeacon / Wi‑Fi Mesh / cloud

**Status:** 💭 staged backlog — **V1** 🔨 [158](158-gd32v-ble-ibeacon.md); **V2** 🔨 [160](160-gd32v-coap-sdk.md); **V3** 🔨 [161](161-gd32v-websocket-sdk.md); **V4** 🔨 [162](162-gd32v-wifi-mesh-sdk.md); V5 not started  
**Depends on:** [137](137-gd32v-wifi-sdk.md), [140](140-gd32v-ble-sdk.md), [143](143-gd32v-sockets-sdk.md), [144](144-gd32v-http-sdk.md), [146](146-gd32v-mqtt-sdk.md), [062](062-targets-esp-rp.md), [105](105-later-tracks-iot.md)

## Verdict

GigaDevice’s [`GD32VW55x_WiFi_BLE_SDK`](https://github.com/GigaDeviceSemiconductor/GD32VW55x_WiFi_BLE_SDK)
ships examples Klin does **not** wrap yet:

| SDK example (approx.) | Klin today |
|---|---|
| `MSDK/examples/ble/peripheral/ble_ibeacon` | 🔨 [158](158-gd32v-ble-ibeacon.md) patch → [`gd32v_ble`](https://github.com/klin-lang/gd32v_ble) `@v0.16.0` |
| `MSDK/examples/wifi/coap` | 🔨 [160](160-gd32v-coap-sdk.md) seed → `gd32v_coap` `@v0.1.0` |
| `MSDK/examples/wifi/websocket_client` | 🔨 [161](161-gd32v-websocket-sdk.md) seed → `gd32v_websocket` `@v0.1.0` |
| `MSDK/examples/wifi/wifi_mesh_smart` | 🔨 [162](162-gd32v-wifi-mesh-sdk.md) seed → `gd32v_wifi_mesh` `@v0.1.0` (**not** BLE Mesh — that is [140](140-gd32v-ble-sdk.md)) |
| `MSDK/examples/cloud/{alicloud,aws,azure}` | — |

Ship these as **separate** external packages (or a thin tag on an existing `gd32v_*`),
**not** folded into `machine_gd32v`, and **not** all in one mega-package.

Already done siblings: Wi‑Fi [137](137-gd32v-wifi-sdk.md), BLE [140](140-gd32v-ble-sdk.md),
sockets [143](143-gd32v-sockets-sdk.md), HTTP [144](144-gd32v-http-sdk.md),
OTA [145](145-gd32v-ota-sdk.md), MQTT [146](146-gd32v-mqtt-sdk.md).

## Stages (do in order)

| # | Track | Likely home | Needs first | MVP sketch |
|---|---|---|---|---|
| **V1** | **iBeacon** advertise (+ optional scan later) | Tag on [`gd32v_ble`](https://github.com/klin-lang/gd32v_ble) | [140](140-gd32v-ble-sdk.md) | 🔨 [158](158-gd32v-ble-ibeacon.md) — UUID / major / minor / measured RSSI as **arguments** |
| **V2** | **CoAP** client | `gd32v_coap` | [137](137-gd32v-wifi-sdk.md) IP + [143](143-gd32v-sockets-sdk.md) | 🔨 [160](160-gd32v-coap-sdk.md) — GET/PUT into **caller** buffers; confirm/non-confirm explicit |
| **V3** | **WebSocket** client | `gd32v_websocket` | [137](137-gd32v-wifi-sdk.md) IP + [143](143-gd32v-sockets-sdk.md) | 🔨 [161](161-gd32v-websocket-sdk.md) — connect + send/recv text/binary; `wss://` later |
| **V4** | **Wi‑Fi Mesh** | `gd32v_wifi_mesh` (sibling of `gd32v_wifi`) | [137](137-gd32v-wifi-sdk.md) | 🔨 [162](162-gd32v-wifi-mesh-sdk.md) — init + `config_rootap` + join status; IP apps after join; **not** BLE Mesh |
| **V5** | **Cloud** (Aliyun / AWS / Azure) | One package **per** vendor **or** deferred until a desk project picks one | Wi‑Fi IP + usually MQTT/HTTP ([146](146-gd32v-mqtt-sdk.md) / [144](144-gd32v-http-sdk.md)) | Thin FFI over SDK `MSDK/examples/cloud/*`; credentials / endpoints **arguments** — no baked-in vendor keys |

V1 Klin docs merged ([158](158-gd32v-ble-ibeacon.md)); upstream `gd32v_ble` `@v0.16.0` tag still awaiting publish.  
V2 Klin docs merged ([160](160-gd32v-coap-sdk.md)); upstream `gd32v_coap` `@v0.1.0` tag awaiting publish.  
V3 Klin docs merged ([161](161-gd32v-websocket-sdk.md)); upstream `gd32v_websocket` `@v0.1.0` tag awaiting publish.  
V4 started at request ([162](162-gd32v-wifi-mesh-sdk.md)).  
Do **not** start V5 until a concrete cloud + device need exists — vendor SDKs are large.

## Rules

1. **One stage at a time.** New numbered issue when implementation starts (this file stays the queue).  
2. Compiler unchanged — external `klin-lang/gd32v_*` (or a tag on an existing one).  
3. Prime rule: no hidden allocation / control flow / cost; SDK heap / tasks stay **SDK contracts** in the package README.  
4. Do **not** vendor `GD32VW55x_WiFi_BLE_SDK` into Klin or the package tree.  
5. Do **not** use `esp_*` packages on VW553 (wrong engine).  
6. Prefer protocol clients over “IoT frameworks”. Cloud = last.

## Out of scope (this issue)

- Implementing V5 here (spawn child issues; V1 → [158](158-gd32v-ble-ibeacon.md); V2 → [160](160-gd32v-coap-sdk.md); V3 → [161](161-gd32v-websocket-sdk.md); V4 → [162](162-gd32v-wifi-mesh-sdk.md))  
- ESP CoAP / WebSocket / Matter twins (→ [105](105-later-tracks-iot.md) / separate ESP tracks)  
- BLE Mesh extras (already [140](140-gd32v-ble-sdk.md))  
- Folding radio into board packs ([138](138-board-gd32vw553h-eval.md) / [139](139-board-gd32vw553h-start.md) / [156](156-board-lckfb-gd32vw553.md))

## Links

- SDK: https://github.com/GigaDeviceSemiconductor/GD32VW55x_WiFi_BLE_SDK  
- Wi‑Fi / BLE / sockets / HTTP / MQTT / CoAP / WS / Mesh: [137](137-gd32v-wifi-sdk.md), [140](140-gd32v-ble-sdk.md), [143](143-gd32v-sockets-sdk.md), [144](144-gd32v-http-sdk.md), [146](146-gd32v-mqtt-sdk.md), [160](160-gd32v-coap-sdk.md), [161](161-gd32v-websocket-sdk.md), [162](162-gd32v-wifi-mesh-sdk.md)  
- IoT later (ESP-shaped): [105](105-later-tracks-iot.md)  
- Targets: [062](062-targets-esp-rp.md)  
