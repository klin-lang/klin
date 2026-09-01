# espnow

Thin **ESP-IDF ESP-NOW** bindings for [Klin](https://github.com/klin-lang/klin)
(connectionless peer / broadcast frames over Wi‑Fi, no IP stack).

The radio is in the **silicon**; this package does **not** belong in
[`machine_esp`](https://github.com/klin-lang/machine_esp) (MMIO Pin…Adc+Rmt MVP).
Same split as [`esp_wifi`](https://github.com/klin-lang/esp_wifi) /
[`esp_ble`](https://github.com/klin-lang/esp_ble) — see Klin
[159](https://github.com/klin-lang/klin/blob/main/issues/159-esp-now-idf.md).

C engine = **ESP-IDF** (`esp_wifi` STA + `esp_now_*`, NVS, event loop). Klin is a
thin FFI client (`@[link("now_idf.c")]` + `@[cimport]`). IDF heap / Wi‑Fi task /
NVS are **IDF contracts**, not hidden Klin allocation.

**ESP-NOW is Espressif-only** (ESP32 / S* / C* with Wi‑Fi). It does not run on
STM32, Pico, AVR, or GD32V. Unencrypted peers on this tag; PMK/LMK later.

Package / module name is **`espnow`** (no underscore) so Klin-emitted C symbols
(`espnow_init`, `espnow_send`, …) do not collide with IDF `esp_now_*`.

## Status (`@v0.1.0`)

| API | Notes |
|---|---|
| `init` / `deinit` / `stop` | NVS + Wi‑Fi STA (no AP assoc) + `esp_now_init` + send/recv CBs |
| `set_channel` / `channel` | Primary channel `1`…`13` (default **1** after `init`) |
| `mac_self` | Copy STA MAC into caller 6-byte buffer |
| `add_peer` / `del_peer` / `peer_exists` | Unencrypted; `channel` 0 = current |
| `add_broadcast` | Peer `ff:ff:ff:ff:ff:ff` (required before broadcast `send`) |
| `send` / `send_wait` / `send_ok` / `send_done` | Poll send CB (no Klin callbacks) |
| `recv_count` / `recv_available` / `recv` | Fixed RX ring (**8**); overflow drops **newest** |
| `data_max` / `recv_queue_max` | **250** / **8** (documented) |
| `log_self` | Debug `printf` of MAC + channel |

`version()` → `1` (`@v0.1.0`).

## Requirements

- [Klin](https://github.com/klin-lang/klin) compiler
- [ESP-IDF](https://docs.espressif.com/projects/esp-idf/) **v5.x** (`IDF_PATH`)
- App `sdkconfig` with Wi‑Fi STA + NVS

## Layout

```text
espnow/
  version.kl
  now.kl              # Klin API
  now_idf.c / .h      # ESP-IDF C glue
examples/peer_s3/     # ESP32-S3 idf.py broadcast demo
examples/smoke/       # emit-c (no IDF)
```

## Usage

```klin
import "github/klin-lang/espnow" now

@[cexport, codename("klin_app_main")]
fn app() {
  let mut e = now.init()
  if e != now.err_ok() {
    return
  }
  e = now.set_channel(6)
  if e != now.err_ok() {
    return
  }
  now.log_self()
  e = now.add_broadcast()
  if e != now.err_ok() {
    return
  }

  let mut bc: [6]u8
  bc[0] = 255
  bc[1] = 255
  bc[2] = 255
  bc[3] = 255
  bc[4] = 255
  bc[5] = 255

  let mut msg: [4]u8
  msg[0] = 1
  msg[1] = 2
  msg[2] = 3
  msg[3] = 4
  e = now.send(cast(*u8, &bc[0]), cast(*u8, &msg[0]), 4)
  if e == now.err_ok() {
    let _w = now.send_wait(2000)
  }

  let mut src: [6]u8
  let mut buf: [250]u8
  while true {
    if now.recv_available() {
      let _n = now.recv(cast(*mut u8, &src[0]), cast(*mut u8, &buf[0]), 250)
    }
  }
}
```

```sh
klin get github/klin-lang/espnow@v0.1.0
```

Offline mirror (this tree):

```sh
klin --emit-c -I patches/espnow-v0.1.0 \
  patches/espnow-v0.1.0/examples/smoke/smoke.kl
```

Local / in-repo:

```klin
import "../../espnow" now
```

## Example (hardware)

```sh
cd examples/peer_s3
. $IDF_PATH/export.sh
make emit KLIN=/path/to/klin/bin/klin.dart
make build
make flash
```

Target: **esp32s3**. Board pack
[`waveshare_esp32_s3_pico`](https://github.com/klin-lang/waveshare_esp32_s3_pico)
stays pin/WS2812-only — no radio API there.

Siblings: [`esp_wifi`](https://github.com/klin-lang/esp_wifi),
[`esp_ble`](https://github.com/klin-lang/esp_ble).

## Contract (prime rule)

- No Klin GC / hidden heap — MAC and payloads are **caller** buffers.
- RX ring depth **8**; overflow drops the newest frame (documented).
- Max payload **250** bytes (`ESP_NOW_MAX_DATA_LEN` / ESP-NOW v1).
- Peers are **unencrypted** on this tag (no PMK/LMK).
- Send completion is polled (`send_wait` / `send_done`) — no Klin callbacks.
- Wi‑Fi STA + ESP-NOW buffers / tasks are **IDF contracts**.
- Errors are `i32` (`esp_err_t`); check them.
- Both peers must use the **same channel**.

## Changelog

| Tag | Notes |
|---|---|
| `@v0.1.0` | init + channel + peers + send/recv poll + broadcast |

## Links

- Klin issue: https://github.com/klin-lang/klin/blob/main/issues/159-esp-now-idf.md
- Pack: https://github.com/klin-lang/espnow
- Tag: https://github.com/klin-lang/espnow/releases/tag/v0.1.0
- Mirror: https://github.com/klin-lang/klin/tree/main/patches/espnow-v0.1.0
- Wi‑Fi sibling: https://github.com/klin-lang/esp_wifi
- BLE sibling: https://github.com/klin-lang/esp_ble
- Chip MMIO: https://github.com/klin-lang/machine_esp
