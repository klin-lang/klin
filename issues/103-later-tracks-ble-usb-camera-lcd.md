# 103 — Later tracks: BLE / USB OTG / camera / Pico LCD shields

**Status:** 💭 backlog (do **one track at a time**; not the current step)  
**Depends on:** [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md), [101](101-esp-wifi-idf.md), [102](102-esp-eth-idf.md)

## Verdict

These are **separate tracks** after the ESP network MVP (`esp_wifi` / `esp_eth`).  
Do **not** fold them into `machine_esp` Pin…Adc(+Rmt) unless the feature is true MMIO with no IDF stack.  
Do **not** expand the scope of whichever step is “current” in [sorted](sorted.md) — pick one track, ship a small package or board-pack slice, then the next.

## Done / in flight (context, not this issue)

| Track | Where |
|---|---|
| Wi‑Fi STA (IDF) | [`esp_wifi`](https://github.com/klin-lang/esp_wifi) → [101](101-esp-wifi-idf.md) ✅ |
| Ethernet (IDF; W5500 first, RMII later) | [`esp_eth`](https://github.com/klin-lang/esp_eth) → [102](102-esp-eth-idf.md) |
| USB CDC poll (RP2350) | `machine_rp` → [095](095-board-waveshare-rp2350-lcd-096.md) ✅ (different from USB **OTG**) |

## Queue (piecemeal)

Work top-down or pick by hardware on the desk. Each row = own issue + package/board work when started.

| # | Track | Likely home | Notes |
|---|---|---|---|
| A | **BLE** | Separate IDF package (e.g. `esp_ble` / NimBLE client) — sibling of [101](101-esp-wifi-idf.md) | Radio in silicon; **not** `machine_*`. Out of scope of `esp_wifi` SoftAP/BLE. |
| B | **USB OTG** | ESP: thin IDF / TinyUSB client package; RP: extend beyond CDC if needed | S3 has USB OTG; distinct from RP `UsbCdc` poll ACM. Host vs device = explicit APIs. |
| C | **Camera** | Separate IDF package (DVP / CSI / `esp_camera`-class) | S3-class; buffers and DMA **caller-visible**; not board-pack MMIO toys. |
| D | **LCD shields (Pico form-factor)** | Board packs + thin display helpers (SPI/I80/PIO as today on [095](095-board-waveshare-rp2350-lcd-096.md)) | Pico-sized shields on RP Pico / Waveshare S3-Pico pinout; pin maps in board pack, not `machine_*`. |

## Rules for each track

1. New Klin issue when work starts (do not implement inside this placeholder).  
2. External repo preferred (compiler unchanged).  
3. Prime rule: no hidden allocation / control flow / cost.  
4. Board pack = pins + glue examples; chip stacks (BLE / camera / USB device class) = own packages.  
5. Freestanding ESP / classic ESP32 / C6 stay under [062](062-targets-esp-rp.md) — not duplicated here.

## Out of scope (this issue)

- Implementation or package scaffolding  
- Priority vs language core  
- Merging BLE into `esp_wifi` or camera into `machine_esp`

## Links

- Targets: [062](062-targets-esp-rp.md)  
- `machine` catalog: [061](061-micropython-machine-api.md)  
- S3 MMIO: [099](099-machine-esp-esp32-s3.md)  
- S3-Pico board: [100](100-board-waveshare-esp32-s3-pico.md)  
- Network: [101](101-esp-wifi-idf.md), [102](102-esp-eth-idf.md)  
