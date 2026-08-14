# 108 — ESP USB OTG as a separate IDF package (`esp_usb`)

**Status:** ✅ published `@v0.1.0` (device CDC-ACM)  
**Depends on:** [021](021-c-libraries.md), [024](024-rtos.md), [049](049-remote-imports.md), [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | External: [`klin-lang/esp_usb`](https://github.com/klin-lang/esp_usb) `@v0.1.0` |
| Engine | **ESP-IDF** v5.x **TinyUSB** (`espressif/esp_tinyusb`) — not MMIO |
| Relation to `machine_esp` | **Separate.** Same class as [`esp_wifi`](https://github.com/klin-lang/esp_wifi) / [`esp_eth`](https://github.com/klin-lang/esp_eth) / [`esp_ble`](https://github.com/klin-lang/esp_ble): IDF stack, not `machine_*`. |
| Relation to RP `UsbCdc` | **Distinct.** RP poll ACM is in [`machine_rp`](https://github.com/klin-lang/machine_rp) ([095](095-board-waveshare-rp2350-lcd-096.md)). ESP USB OTG is TinyUSB device (and later host) in this package. |
| µPython analogy | Outside `machine` — closer to `USBDevice` / port USB CDC ([061](061-micropython-machine-api.md)). |

## Why not `machine_esp.Usb`?

[`machine_esp`](https://github.com/klin-lang/machine_esp) is approach **C** — thin Klin over **explicit MMIO**. USB OTG needs TinyUSB (descriptors, endpoints, FreeRTOS task). Folding that into `machine_*` would hide IDF cost and break the MMIO contract. Pattern matches [`esp_wifi`](https://github.com/klin-lang/esp_wifi) / [`esp_ble`](https://github.com/klin-lang/esp_ble): C engine + Klin FFI client ([024](024-rtos.md)).

Board pack [100](100-board-waveshare-esp32-s3-pico.md) stays pins/WS2812/buses — **no** USB API there either.

Track B from [103](103-later-tracks-ble-usb-camera-lcd.md).

## Scope

### `@v0.1.0` — device CDC-ACM

- `cdc_init` — TinyUSB driver + CDC-ACM0  
- `cdc_connected` — host DTR asserted  
- `cdc_read` / `cdc_write` — caller buffers; RX staging max `cdc_rx_max()` (**256** bytes)  
- `cdc_stop` — mark idle  
- `version()` → `1`  
- Implementation: `@[link("cdc_idf.c")]` + `@[cimport, cheader]`  
- Example: `examples/cdc_s3/` (ESP32-S3, `idf.py` + `espressif/esp_tinyusb ^1`)  
- Smoke: `examples/smoke/` (host stubs)

### Later (not this tag)

- USB **host** (MSC / HID / CDC host) — explicit APIs, separate tags  
- Extra device classes (HID / MSC / MIDI)  
- Multi-CDC / custom descriptors beyond TinyUSB defaults  

## Out of scope

- Folding USB into `machine_esp` or board packs  
- Freestanding (no IDF / no TinyUSB)  
- RP `UsbCdc` changes (stay in `machine_rp`)  
- Camera / Pico LCD shields — camera DVP JPEG ✅ [109](109-esp-camera-idf.md); Pico-LCD-1.14 ✅ [110](110-board-waveshare-pico-lcd-114.md)

## Contract (prime rule)

- No Klin GC / hidden heap — TX/RX payloads are buffers you pass.  
- RX staging is a **fixed 256-byte** ring replace (overflow drops prior unread).  
- TinyUSB task / endpoint buffers are **IDF contracts**.  
- Errors are `i32` (0 = OK).  
- Requires SoC with USB-OTG (ESP32-S2 / S3 / P4) and `CONFIG_TINYUSB_CDC_ENABLED=y`.

## Usage (device CDC)

```klin
import "github/klin-lang/esp_usb" usb

@[cexport, codename("klin_app_main")]
fn app() {
  let mut e = usb.cdc_init()
  if e != usb.err_ok() {
    return
  }
  while !usb.cdc_connected() {
  }
  let mut hi: [5]u8
  hi[0] = 104
  hi[1] = 101
  hi[2] = 108
  hi[3] = 108
  hi[4] = 111
  let _w = usb.cdc_write(cast(*u8, &hi[0]), 5)
}
```

```sh
klin get github/klin-lang/esp_usb@v0.1.0
```

## Links

- Repo: https://github.com/klin-lang/esp_usb  
- Tag: [v0.1.0](https://github.com/klin-lang/esp_usb/releases/tag/v0.1.0)  
- Parent backlog: [103](103-later-tracks-ble-usb-camera-lcd.md) (track B)  
- Wi‑Fi sibling: [101](101-esp-wifi-idf.md) / [`esp_wifi`](https://github.com/klin-lang/esp_wifi)  
- Ethernet sibling: [102](102-esp-eth-idf.md) / [`esp_eth`](https://github.com/klin-lang/esp_eth)  
- BLE sibling: [106](106-esp-ble-idf.md) / [`esp_ble`](https://github.com/klin-lang/esp_ble)  
- Camera sibling: [109](109-esp-camera-idf.md) / [`esp_camera`](https://github.com/klin-lang/esp_camera)  
- Pico LCD shield: [110](110-board-waveshare-pico-lcd-114.md) / [`waveshare_pico_lcd_114`](https://github.com/klin-lang/waveshare_pico_lcd_114)  
- RP USB CDC (different): [095](095-board-waveshare-rp2350-lcd-096.md) / [`machine_rp`](https://github.com/klin-lang/machine_rp)  
- Chip MMIO: [099](099-machine-esp-esp32-s3.md) / [`machine_esp`](https://github.com/klin-lang/machine_esp)  
- Board (no USB API): [100](100-board-waveshare-esp32-s3-pico.md)  
- Catalog: [061](061-micropython-machine-api.md), targets [062](062-targets-esp-rp.md)  
- RTOS FFI pattern: [024](024-rtos.md) / [028](028-freertos.md)
