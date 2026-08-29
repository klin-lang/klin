# 146 — GD32VW553 MQTT **client** as a separate SDK package (`gd32v_mqtt`)

**Status:** ✅ [`gd32v_mqtt@v0.1.0`](https://github.com/klin-lang/gd32v_mqtt/releases/tag/v0.1.0) published (MQTT 3.1.1 **client**; QoS0; host `klin test` PASS)  
**Depends on:** [021](021-c-libraries.md), [024](024-rtos.md), [049](049-remote-imports.md), [137](137-gd32v-wifi-sdk.md) (IP first), [143](143-gd32v-sockets-sdk.md) (TCP sibling; not a hard link dep), [062](062-targets-esp-rp.md), [105](105-later-tracks-iot.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | External: [`klin-lang/gd32v_mqtt`](https://github.com/klin-lang/gd32v_mqtt) `@v0.1.0` |
| Engine | **MQTT 3.1.1 client** over LwIP TCP (+ optional mbedTLS + **caller PEM**) — not MMIO, **not** ESP-IDF `esp-mqtt` |
| Client vs broker | **Client only.** No broker / gateway in this package. |
| Relation to `gd32v_sockets` | **Sibling.** Sockets = raw TCP/UDP. This package speaks MQTT on a TCP (or TLS) connection. |
| Relation to `gd32v_wifi` | **Separate.** Connect **after** IP. |
| ESP twin | None yet ([105](105-later-tracks-iot.md) I1). |

## Why not fold into `gd32v_sockets` / `gd32v_wifi`?

MQTT is a protocol contract (topics, QoS, client id, credentials). Keeping it separate matches [105](105-later-tracks-iot.md) and the HTTP/OTA split.

## Scope (`@v0.1.0`)

- `connect` / `connect_tls_pem` — broker host + port + **explicit** `client_id` (+ optional user/pass strings; empty = none)  
- `disconnect`  
- `publish` — topic + **caller** payload; **QoS 0** only in MVP  
- `subscribe` — topic filter; QoS 0  
- `poll` — non-blocking-ish read of one inbound PUBLISH into **caller** topic/payload buffers (returns payload bytes, `0` if none, `-1` on error)  
- `err_ok` / `version()` → `1`  
- Implementation: `@[link("mqtt_sdk.c")]` + `@[cimport]` (`klin_gd32v_mqtt_*`)  
- Host `klin test` stubs when `lwip/sockets.h` is absent  
- Smoke: `examples/smoke/`; sketch: `examples/mqtt_pub/`

## Out of scope

- MQTT **broker** / bridge  
- QoS 1/2, retained messages, Last Will (later tags)  
- Automatic reconnect / hidden keepalive task heap in Klin (keepalive may be explicit later)  
- Bringing up Wi‑Fi (→ [137](137-gd32v-wifi-sdk.md))  
- OTA (→ [145](145-gd32v-ota-sdk.md))  
- CoAP / WebSocket / cloud — [157](157-later-tracks-gd32v-coap-ws-ibeacon-mesh-cloud.md)  
- Changing the Klin compiler  
- ESP-IDF `esp_mqtt` on VW553  

## Contract (prime rule)

- No Klin GC / hidden heap — payloads and topic strings are caller buffers / args.  
- Client id and credentials are **arguments** — no baked-in cloud vendor.  
- Transport errors / protocol failures → `-1`.  

## Usage (after Wi‑Fi IP)

```klin
import "github/klin-lang/gd32v_wifi" wifi
import "github/klin-lang/gd32v_mqtt" mqtt

fn main() {
    let mut e = wifi.sta_init()
    e = wifi.sta_connect("myssid", "mypass")
    e = wifi.sta_wait_ip(20000)
    if e != wifi.err_ok() {
        return
    }
    e = mqtt.connect("192.168.1.10", 1883, "klin-node-1", "", "")
    if e != mqtt.err_ok() {
        return
    }
    let mut msg: [5]u8
    msg[0] = 104
    msg[1] = 101
    msg[2] = 108
    msg[3] = 108
    msg[4] = 111
    e = mqtt.publish("klin/hello", cast(*u8, &msg[0]), 5)
    let _d = mqtt.disconnect()
}
```

```sh
klin get github/klin-lang/gd32v_mqtt@v0.1.0
```

## Links

- Repo: https://github.com/klin-lang/gd32v_mqtt  
- Tag: [v0.1.0](https://github.com/klin-lang/gd32v_mqtt/releases/tag/v0.1.0)  
- Sockets: [143](143-gd32v-sockets-sdk.md)  
- Wi‑Fi: [137](137-gd32v-wifi-sdk.md)  
- IoT backlog: [105](105-later-tracks-iot.md)  
