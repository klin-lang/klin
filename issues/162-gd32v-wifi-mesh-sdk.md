# 162 — `gd32v_wifi_mesh` Wi‑Fi Mesh-Smart (`@v0.1.0`)

**Status:** 🔨 seed [`patches/gd32v_wifi_mesh-v0.1.0/`](../patches/gd32v_wifi_mesh-v0.1.0/)
(awaiting upstream [`klin-lang/gd32v_wifi_mesh`](https://github.com/klin-lang/gd32v_wifi_mesh) `@v0.1.0`)  
**Depends on:** [021](021-c-libraries.md), [024](024-rtos.md), [049](049-remote-imports.md),
[137](137-gd32v-wifi-sdk.md) (Wi‑Fi management first),
[062](062-targets-esp-rp.md), [105](105-later-tracks-iot.md),
[157](157-later-tracks-gd32v-coap-ws-ibeacon-mesh-cloud.md) V4  
**Parent queue:** [157](157-later-tracks-gd32v-coap-ws-ibeacon-mesh-cloud.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | External: `klin-lang/gd32v_wifi_mesh`; seed under `patches/` until published |
| Engine | GigaDevice **Wi‑Fi Mesh-Smart** (`wifi_mesh_smart`, `CONFIG_WIFI_MESH_SMART`) — not MMIO, not ESP-IDF, **not** BLE Mesh |
| Relation to `gd32v_wifi` | **Sibling.** Mesh assumes Wi‑Fi management already up (`sta_init` / SDK `wifi_init`). |
| Relation to BLE Mesh | **Separate.** BLE Mesh is [`gd32v_ble`](https://github.com/klin-lang/gd32v_ble) [140](140-gd32v-ble-sdk.md). |
| “Send” after join | Use IP packages ([143](143-gd32v-sockets-sdk.md) / [146](146-gd32v-mqtt-sdk.md) / …). No mesh-only datagram API in `@v0.1.0`. |

## Why not fold into `gd32v_wifi`?

Mesh-Smart is a distinct self-organizing SoftAP/STA tree (Vendor IE, roles, NVDS
root credentials). Keeping it separate matches [157](157-later-tracks-gd32v-coap-ws-ibeacon-mesh-cloud.md) V4
and avoids bloating the STA/SoftAP surface.

## Scope (`@v0.1.0`)

- `init()` — `wifi_mesh_smart_network_init` (async self-organize)  
- `config_rootap(ssid, password)` — Root AP credentials (caller strings)  
- `softap_stop()`  
- `started` / `joined` — init flag / `STA_CONNECTED_SOFTAP_STARTED`  
- `status` / `role` / `level` / `node_id` — snapshot via SDK `mesh_smart_info`  
- `role_root` / `role_router` / `role_leaf`  
- `err_ok` / `version()` → `1`  
- Host stubs when `wifi_mesh_smart.h` absent  
- Smoke: `examples/smoke/`; board sketch: `examples/mesh_root/`

### Later (not this tag)

- Explicit SoftAP SSID / OUI / max-level arguments (today SDK defaults)  
- Event callbacks into Klin  
- Mesh-only datagram send (if SDK adds a public API)  
- Folding into `gd32v_wifi`  

## Out of scope

- BLE Mesh ([140](140-gd32v-ble-sdk.md))  
- Cloud vendor SDKs ([157](157-later-tracks-gd32v-coap-ws-ibeacon-mesh-cloud.md) V5)  
- Vendoring `GD32VW55x_WiFi_BLE_SDK` into the package tree  
- Changing the Klin compiler  

## Contract (prime rule)

- No Klin GC / hidden heap — SSID/password are caller strings; SDK tasks / NVDS /
  SoftAP stay **SDK contracts**.  
- Errors → `-1`.  

## Usage

```sh
klin get github/klin-lang/gd32v_wifi_mesh@v0.1.0
```

Until publish:

```sh
klin test patches/gd32v_wifi_mesh-v0.1.0/gd32v_wifi_mesh
```

## Links

- Seed: [`patches/gd32v_wifi_mesh-v0.1.0/`](../patches/gd32v_wifi_mesh-v0.1.0/)  
- Planned repo: https://github.com/klin-lang/gd32v_wifi_mesh  
- SDK example: `MSDK/examples/wifi/wifi_mesh_smart`  
- Wi‑Fi sibling: [137](137-gd32v-wifi-sdk.md)  
- Queue: [157](157-later-tracks-gd32v-coap-ws-ibeacon-mesh-cloud.md)
