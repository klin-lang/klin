# 158 — `gd32v_ble` Apple iBeacon advertise (`@v0.16.0`)

**Status:** 🔨 patch [`patches/gd32v_ble-v0.16.0-ibeacon.patch`](../patches/gd32v_ble-v0.16.0-ibeacon.patch)
(+ notes [`patches/gd32v_ble-v0.16.0-ibeacon/`](../patches/gd32v_ble-v0.16.0-ibeacon/)) — awaiting upstream
[`klin-lang/gd32v_ble`](https://github.com/klin-lang/gd32v_ble) `@v0.16.0`  
**Depends on:** [140](140-gd32v-ble-sdk.md), [157](157-later-tracks-gd32v-coap-ws-ibeacon-mesh-cloud.md) V1  
**Parent queue:** [157](157-later-tracks-gd32v-coap-ws-ibeacon-mesh-cloud.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | Tag on [`gd32v_ble`](https://github.com/klin-lang/gd32v_ble) `@v0.16.0` (not a new package) |
| Engine | GigaDevice VW55x BLE SDK — `ble_adv_create` / manuf data (SDK `ble_ibeacon` example), **not** NimBLE |
| New package? | **No** — thin API on existing [140](140-gd32v-ble-sdk.md) |

## Scope (`@v0.16.0`)

- `ibeacon_advertise(uuid16: *u8, major, minor, measured_pwr): i32` — non-connectable Apple iBeacon  
- Fixed company id `0x004C`; proximity type `0x02 0x15` + 16-byte UUID + major/minor BE + measured power  
- Args only — no hidden adv buffer beyond a fixed 23-byte C payload  
- `ibeacon_company_id()` → `0x004C`  
- `wait_connected` fails while iBeacon is active (non-connectable)  
- `stop_advertise` / `stop` tear down the iBeacon set  
- Host stubs when SDK headers absent; `version()` → `16`  
- Example `examples/ibeacon/`

### Later (not this tag)

- iBeacon **scan** / parse (optional follow-up)  
- Eddystone / other beacon formats  

## Out of scope

- CoAP / WebSocket / Wi‑Fi Mesh / cloud ([157](157-later-tracks-gd32v-coap-ws-ibeacon-mesh-cloud.md) V2+)  
- Folding BLE into `machine_gd32v` or board packs  
- Vendoring `GD32VW55x_WiFi_BLE_SDK`  

## Contract (prime rule)

- No Klin GC / hidden heap — UUID is a caller pointer; payload is a fixed static in C.  
- SDK heap / BLE task / `ble_adv_*` remain **SDK contracts**.  
- Apple iBeacon licensing is the app’s responsibility: https://developer.apple.com/ibeacon/

## Usage

```sh
klin get github/klin-lang/gd32v_ble@v0.16.0
```

Until publish, apply the patch on a `v0.15.0` checkout then `klin test gd32v_ble`
(see [`patches/gd32v_ble-v0.16.0-ibeacon/README.md`](../patches/gd32v_ble-v0.16.0-ibeacon/README.md)).

```klin
import "github/klin-lang/gd32v_ble" ble

fn main() {
    let mut uuid: [16]u8
    let mut e = ble.init()
    e = ble.ibeacon_advertise(cast(*u8, &uuid[0]), 0x1111, 0x2222, 0 - 61)
}
```

## Links

- Patch: [`patches/gd32v_ble-v0.16.0-ibeacon.patch`](../patches/gd32v_ble-v0.16.0-ibeacon.patch)  
- Notes: [`patches/gd32v_ble-v0.16.0-ibeacon/`](../patches/gd32v_ble-v0.16.0-ibeacon/)  
- Upstream: https://github.com/klin-lang/gd32v_ble  
- SDK example: `MSDK/examples/ble/peripheral/ble_ibeacon`  
- BLE package: [140](140-gd32v-ble-sdk.md)  
- Queue: [157](157-later-tracks-gd32v-coap-ws-ibeacon-mesh-cloud.md)
