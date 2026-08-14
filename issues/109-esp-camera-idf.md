# 109 — ESP camera as a separate IDF package (`esp_camera`)

**Status:** ✅ published `@v0.1.0` (DVP JPEG capture)  
**Depends on:** [021](021-c-libraries.md), [024](024-rtos.md), [049](049-remote-imports.md), [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | External: [`klin-lang/esp_camera`](https://github.com/klin-lang/esp_camera) `@v0.1.0` |
| Engine | **ESP-IDF** v5.x + [`espressif/esp32-camera`](https://components.espressif.com/components/espressif/esp32-camera) — not MMIO |
| Relation to `machine_esp` | **Separate.** Same class as [`esp_wifi`](https://github.com/klin-lang/esp_wifi) / [`esp_eth`](https://github.com/klin-lang/esp_eth) / [`esp_ble`](https://github.com/klin-lang/esp_ble) / [`esp_usb`](https://github.com/klin-lang/esp_usb): IDF stack, not `machine_*`. |
| µPython analogy | Outside `machine` — closer to `esp.camera` / port camera APIs ([061](061-micropython-machine-api.md)). |

## Why not `machine_esp.Camera`?

[`machine_esp`](https://github.com/klin-lang/machine_esp) is approach **C** — thin Klin over **explicit MMIO**. Camera needs the esp32-camera driver (SCCB detect, DVP/LCD_CAM DMA, frame buffers in PSRAM/DRAM). Folding that into `machine_*` would hide IDF cost and break the MMIO contract. Pattern matches [`esp_wifi`](https://github.com/klin-lang/esp_wifi) / [`esp_usb`](https://github.com/klin-lang/esp_usb): C engine + Klin FFI client ([024](024-rtos.md)).

Board pack [100](100-board-waveshare-esp32-s3-pico.md) stays pins/WS2812/buses — **no** camera API there either (S3-Pico has no cam connector in MVP).

Track C from [103](103-later-tracks-ble-usb-camera-lcd.md).

## Scope

### `@v0.1.0` — DVP JPEG capture

- `set_pins(...)` before `init` (or presets `pins_freenove_s3` / `pins_ai_thinker`)  
- `set_framesize` / `set_jpeg_quality` / `set_xclk_hz` / `set_fb_count` / `set_fb_in_psram` — before `init`  
- Defaults: JPEG **QVGA**, quality **12**, **1** FB in **PSRAM**  
- `init` — sensor detect + IDF frame buffers / DMA  
- `capture(out, max_len)` — copy one JPEG into **caller** buffer; oversized → `ESP_ERR_NO_MEM` + `last_len()`  
- `width` / `height` / `last_len` — last frame metadata  
- `stop` — `esp_camera_deinit`  
- `version()` → `1`  
- Implementation: `@[link("cam_idf.c")]` + `@[cimport, cheader]`  
- Example: `examples/jpeg_s3/` (Freenove ESP32-S3 CAM)  
- Smoke: `examples/smoke/` (host stubs)

### Later (not this tag)

- CSI / MIPI (P4-class)  
- RGB565 / YUV continuous stream helpers  
- HTTP MJPEG / Wi‑Fi streaming (compose with [`esp_wifi`](https://github.com/klin-lang/esp_wifi))  
- Extra sensor tuning beyond quality/framesize  

## Out of scope

- Folding camera into `machine_esp` or board packs  
- Freestanding (no IDF / no esp32-camera)  
- Pico LCD shields — ✅ [110](110-board-waveshare-pico-lcd-114.md) (other sizes later)  
- USB host webcam class — [`esp_usb`](https://github.com/klin-lang/esp_usb) later tags  

## Contract (prime rule)

- No Klin GC / hidden heap — JPEG lands in **your** buffer.  
- Driver frame buffers / DMA are **IDF / esp32-camera contracts**.  
- Pins / framesize / quality only **before** `init`.  
- Errors are `i32` (0 = OK).  
- SoC: ESP32 / S2 / **S3** with DVP; PSRAM recommended for VGA+.  

## Usage (JPEG QVGA)

```klin
import "github/klin-lang/esp_camera" cam

@[cexport, codename("klin_app_main")]
fn app() {
  let mut e = cam.pins_freenove_s3()
  if e != cam.err_ok() {
    return
  }
  e = cam.set_framesize(cam.framesize_qvga())
  if e != cam.err_ok() {
    return
  }
  e = cam.init()
  if e != cam.err_ok() {
    return
  }
  let mut buf: [65536]u8
  let n = cam.capture(cast(*mut u8, &buf[0]), cam.jpeg_soft_max())
  if n < 1 {
    return
  }
  let _w = cam.width()
  let _h = cam.height()
}
```

```sh
klin get github/klin-lang/esp_camera@v0.1.0
```

## Links

- Repo: https://github.com/klin-lang/esp_camera  
- Tag: [v0.1.0](https://github.com/klin-lang/esp_camera/releases/tag/v0.1.0)  
- Parent backlog: [103](103-later-tracks-ble-usb-camera-lcd.md) (track C)  
- Wi‑Fi sibling: [101](101-esp-wifi-idf.md) / [`esp_wifi`](https://github.com/klin-lang/esp_wifi)  
- Ethernet sibling: [102](102-esp-eth-idf.md) / [`esp_eth`](https://github.com/klin-lang/esp_eth)  
- BLE sibling: [106](106-esp-ble-idf.md) / [`esp_ble`](https://github.com/klin-lang/esp_ble)  
- USB sibling: [108](108-esp-usb-idf.md) / [`esp_usb`](https://github.com/klin-lang/esp_usb)  
- Pico LCD shield: [110](110-board-waveshare-pico-lcd-114.md) / [`waveshare_pico_lcd_114`](https://github.com/klin-lang/waveshare_pico_lcd_114)  
- Chip MMIO: [099](099-machine-esp-esp32-s3.md) / [`machine_esp`](https://github.com/klin-lang/machine_esp)  
- Board (no camera API): [100](100-board-waveshare-esp32-s3-pico.md)  
- Catalog: [061](061-micropython-machine-api.md), targets [062](062-targets-esp-rp.md)  
- RTOS FFI pattern: [024](024-rtos.md) / [028](028-freertos.md)
