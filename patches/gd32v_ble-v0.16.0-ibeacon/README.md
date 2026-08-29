# gd32v_ble `@v0.16.0` — Apple iBeacon advertise (V1)

Patch for [`klin-lang/gd32v_ble`](https://github.com/klin-lang/gd32v_ble)
when the cloud agent cannot push the upstream tag. Klin issue:
[158](../../issues/158-gd32v-ble-ibeacon.md) (queue [157](../../issues/157-later-tracks-gd32v-coap-ws-ibeacon-mesh-cloud.md) V1).

## Apply against `v0.15.0`

```sh
cd /path/to/gd32v_ble
git checkout v0.15.0
git apply /path/to/klin/patches/gd32v_ble-v0.16.0-ibeacon.patch
klin test gd32v_ble
# then tag v0.16.0 when publishing
```

Sibling patch file: [`../gd32v_ble-v0.16.0-ibeacon.patch`](../gd32v_ble-v0.16.0-ibeacon.patch).

## API (`@v0.16.0`)

| Symbol | Meaning |
|---|---|
| `ibeacon_advertise(uuid16, major, minor, measured_pwr)` | Non-connectable Apple iBeacon (`ble_adv_*`, company `0x004C`) |
| `ibeacon_company_id()` | `0x004C` |
| `version()` | `16` |

- `uuid16` — 16-byte proximity UUID (caller buffer; fixed 23-byte C payload)
- `major` / `minor` — `0..=65535` (big-endian on air)
- `measured_pwr` — calibrated RSSI at 1 m as signed int8 (`-128..=127`)
- Stops any prior advertise; `wait_connected` fails while iBeacon is active

Apple licensing: https://developer.apple.com/ibeacon/

Engine remains GigaDevice VW55x BLE SDK (AN152), same as [140](../../issues/140-gd32v-ble-sdk.md).
