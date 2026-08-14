# 103 — Later tracks: USB OTG / camera / Pico LCD shields

**Status:** ✅ tracks A–D MVP shipped (remaining = later tags / sibling LCD sizes)  
**Depends on:** [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md), [101](101-esp-wifi-idf.md), [102](102-esp-eth-idf.md), [106](106-esp-ble-idf.md), [108](108-esp-usb-idf.md), [109](109-esp-camera-idf.md), [110](110-board-waveshare-pico-lcd-114.md)

## Verdict

These are **separate tracks** after the ESP network / BLE / USB / camera / Pico LCD MVP.  
Do **not** fold them into `machine_esp` Pin…Adc(+Rmt) unless the feature is true MMIO with no IDF stack.  
Do **not** expand the scope of whichever step is “current” in [sorted](sorted.md) — pick one track, ship a small package or board-pack slice, then the next.

## Done / in flight (context, not this issue)

| Track | Where |
|---|---|
| Wi‑Fi STA (IDF) | [`esp_wifi`](https://github.com/klin-lang/esp_wifi) → [101](101-esp-wifi-idf.md) ✅ |
| Ethernet (IDF; W5500 first, RMII later) | [`esp_eth`](https://github.com/klin-lang/esp_eth) → [102](102-esp-eth-idf.md) ✅ (RMII / other chips → [104](104-later-tracks-esp-network.md)) |
| BLE peripheral + central + GATT + bond + UUID16/128 + privacy + Mesh OnOff (IDF NimBLE) | [`esp_ble`](https://github.com/klin-lang/esp_ble) → [106](106-esp-ble-idf.md) ✅ `@v0.10.0` |
| USB OTG device CDC-ACM (IDF TinyUSB) | [`esp_usb`](https://github.com/klin-lang/esp_usb) → [108](108-esp-usb-idf.md) ✅ `@v0.1.0` (host / other classes later) |
| Camera DVP JPEG (IDF esp32-camera) | [`esp_camera`](https://github.com/klin-lang/esp_camera) → [109](109-esp-camera-idf.md) ✅ `@v0.1.0` (CSI / RGB stream later) |
| Pico LCD shield (ST7789 1.14") | [`waveshare_pico_lcd_114`](https://github.com/klin-lang/waveshare_pico_lcd_114) → [110](110-board-waveshare-pico-lcd-114.md) ✅ `@v0.1.0` (font/S3 SPI / other sizes later) |
| USB CDC poll (RP2350) | `machine_rp` → [095](095-board-waveshare-rp2350-lcd-096.md) ✅ (different from USB **OTG**) |
| Integrated RP2350-LCD-0.96 | [095](095-board-waveshare-rp2350-lcd-096.md) ✅ (not a shield) |

## Queue (piecemeal)

| # | Track | Likely home | Notes |
|---|---|---|---|
| A | **BLE** | ✅ shipped → [106](106-esp-ble-idf.md) / [`esp_ble`](https://github.com/klin-lang/esp_ble) `@v0.10.0` | Advertise + GATT + scan/client + bond + UUID16/128 + multi-svc + passkey + privacy + Mesh OnOff done. |
| B | **USB OTG** | ✅ device CDC shipped → [108](108-esp-usb-idf.md) / [`esp_usb`](https://github.com/klin-lang/esp_usb) `@v0.1.0` | TinyUSB CDC-ACM done; host / HID / MSC / MIDI = later tags on same package. Distinct from RP `UsbCdc`. |
| C | **Camera** | ✅ DVP JPEG shipped → [109](109-esp-camera-idf.md) / [`esp_camera`](https://github.com/klin-lang/esp_camera) `@v0.1.0` | Caller-owned JPEG buffer; CSI / RGB565 stream / MJPEG = later tags. Not board-pack MMIO. |
| D | **LCD shields (Pico form-factor)** | ✅ 1.14" shipped → [110](110-board-waveshare-pico-lcd-114.md) / [`waveshare_pico_lcd_114`](https://github.com/klin-lang/waveshare_pico_lcd_114) `@v0.1.0` | ST7789 fill/rects; font / S3 SPI / other shield sizes = later. Distinct from integrated [095](095-board-waveshare-rp2350-lcd-096.md). |

## Rules for each track

1. New Klin issue when work starts (do not implement inside this placeholder).  
2. External repo preferred (compiler unchanged).  
3. Prime rule: no hidden allocation / control flow / cost.  
4. Board pack = pins + glue examples; chip stacks (BLE / camera / USB device class) = own packages.  
5. Freestanding ESP / classic ESP32 / C6 stay under [062](062-targets-esp-rp.md) — not duplicated here.  
6. SoftAP / RMII / dual Wi‑Fi+ETH / sockets stay under [104](104-later-tracks-esp-network.md) — not duplicated here.

## Out of scope (this issue)

- Implementation or package scaffolding  
- Priority vs language core  
- Merging camera into `machine_esp` or folding USB into board packs  
- ESP network package later tags (→ [104](104-later-tracks-esp-network.md))
- Re-implementing BLE advertise / GATT / scan MVP (→ [106](106-esp-ble-idf.md))
- Re-implementing USB device CDC MVP (→ [108](108-esp-usb-idf.md))
- Re-implementing camera DVP JPEG MVP (→ [109](109-esp-camera-idf.md))
- Re-implementing Pico-LCD-1.14 MVP (→ [110](110-board-waveshare-pico-lcd-114.md))
## Links

- Targets: [062](062-targets-esp-rp.md)  
- `machine` catalog: [061](061-micropython-machine-api.md)  
- S3 MMIO: [099](099-machine-esp-esp32-s3.md)  
- S3-Pico board: [100](100-board-waveshare-esp32-s3-pico.md)  
- Network MVP: [101](101-esp-wifi-idf.md), [102](102-esp-eth-idf.md)  
- BLE MVP: [106](106-esp-ble-idf.md)  
- USB OTG MVP: [108](108-esp-usb-idf.md)  
- Camera MVP: [109](109-esp-camera-idf.md)  
- Pico LCD shield MVP: [110](110-board-waveshare-pico-lcd-114.md)  
- Network later: [104](104-later-tracks-esp-network.md)  
- IoT later (maybe): [105](105-later-tracks-iot.md)  
