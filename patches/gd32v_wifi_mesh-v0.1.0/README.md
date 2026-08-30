# gd32v_wifi_mesh

Thin **GD32VW55x Wi‑Fi Mesh-Smart** package for
[Klin](https://github.com/klin-lang/klin).

Wraps GigaDevice `wifi_mesh_smart` (`CONFIG_WIFI_MESH_SMART=1`). Nodes
self-organize (ROOT / ROUTER / LEAF), join via Mesh SoftAP beacons, and form a
tree. **Not** BLE Mesh — that is [`gd32v_ble`](https://github.com/klin-lang/gd32v_ble).

Sibling of [`gd32v_wifi`](https://github.com/klin-lang/gd32v_wifi): bring up
Wi‑Fi management first (`sta_init` / SDK `wifi_init`), then `mesh.init()`.

After a node has joined, use normal IP clients ([`gd32v_sockets`](https://github.com/klin-lang/gd32v_sockets),
MQTT, …). There is **no** separate mesh datagram `send` in `@v0.1.0`.

## Status (`@v0.1.0`)

| API | Notes |
|---|---|
| `init` | `wifi_mesh_smart_network_init` (async self-organize) |
| `config_rootap(ssid, pass)` | Root AP credentials (first-boot provisioning) |
| `softap_stop` | Stop this node's Mesh SoftAP |
| `started` / `joined` | Init flag / `STA_CONNECTED_SOFTAP_STARTED` |
| `status` / `role` / `level` / `node_id` | Snapshot from SDK `mesh_smart_info` |
| `role_root` / `role_router` / `role_leaf` | `0` / `1` / `2` |
| `err_ok` / `version` | Helpers (`version()` → `1`) |

## Requirements

- [Klin](https://github.com/klin-lang/klin) compiler
- [`GD32VW55x_WiFi_BLE_SDK`](https://github.com/GigaDeviceSemiconductor/GD32VW55x_WiFi_BLE_SDK) with `CONFIG_WIFI_MESH_SMART`
- Wi‑Fi management already initialized ([`gd32v_wifi`](https://github.com/klin-lang/gd32v_wifi))

## Usage

```klin
import "github/klin-lang/gd32v_wifi" wifi
import "github/klin-lang/gd32v_wifi_mesh" mesh

fn main() {
    let mut e = wifi.sta_init()
    e = mesh.init()
    e = mesh.config_rootap("myssid", "mypass")
}
```

```sh
klin get github/klin-lang/gd32v_wifi_mesh@v0.1.0
```

Until publish, use this seed:

```sh
klin test patches/gd32v_wifi_mesh-v0.1.0/gd32v_wifi_mesh
klin run patches/gd32v_wifi_mesh-v0.1.0/examples/smoke/smoke.kl
```

## Links

- Klin issue: [162](https://github.com/klin-lang/klin/blob/main/issues/162-gd32v-wifi-mesh-sdk.md)
- Queue: [157](https://github.com/klin-lang/klin/blob/main/issues/157-later-tracks-gd32v-coap-ws-ibeacon-mesh-cloud.md) V4
- SDK example: `MSDK/examples/wifi/wifi_mesh_smart`
