# 145 — GD32VW553 OTA (FOTA) as a separate SDK package (`gd32v_ota`)

**Status:** ✅ [`gd32v_ota@v0.1.0`](https://github.com/klin-lang/gd32v_ota/releases/tag/v0.1.0) published (ping‑pong MSDK + HTTP(S) PEM; host `klin test` PASS)  
**Depends on:** [021](021-c-libraries.md), [024](024-rtos.md), [049](049-remote-imports.md), [137](137-gd32v-wifi-sdk.md) (IP first), [144](144-gd32v-http-sdk.md) (HTTPS/PEM sibling; not a hard link dep), [062](062-targets-esp-rp.md), [105](105-later-tracks-iot.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | External: [`klin-lang/gd32v_ota`](https://github.com/klin-lang/gd32v_ota) `@v0.1.0` |
| Engine | GigaDevice **ping‑pong MSDK** (`raw_flash_*` + `rom_sys_*` image flags) + HTTP(S) download (LwIP / mbedTLS + **caller PEM**) — not MMIO, **not** ESP-IDF |
| Relation to `gd32v_http` | **Sibling.** HTTP = generic client. This package **streams** an `image-ota.bin` into the inactive flash slot. |
| Relation to `gd32v_wifi` | **Separate.** Call OTA **after** IP. |
| ESP twin | None yet ([105](105-later-tracks-iot.md) I2). Not [`esp_http`](https://github.com/klin-lang/esp_http). |

## Why not fold into `gd32v_http`?

OTA is flash + boot flags + reboot. Folding it into HTTP would hide erase/write cost and couple every GET to firmware layout (AN260 / `ota_demo.c`).

## Scope (`@v0.1.0`)

- `begin` — pick inactive MSDK slot (`rom_sys_status_get` / offsets) → `0` / `-1`  
- `write` — erase-as-needed + `raw_flash_write` into that slot; **caller buffer**  
- `abort` — drop session (no boot-flag change)  
- `finish` — mark new image `NEWER` / running `OLDER` (`rom_sys_set_img_flag`) → `0` / `-1`  
- `reboot` — soft reset (device); host stub is a no-op  
- `download_http` / `download_https_pem` — stream GET body into `write` (PEM **explicit**; no IDF crt bundle)  
- `bytes_written` / `last_http_status` / `err_ok` / `version()` → `1`  
- Implementation: `@[link("ota_sdk.c")]` + `@[cimport]` (`klin_gd32v_ota_*`)  
- Host `klin test` stubs when `raw_flash_api.h` / `rom_export.h` are absent  
- Smoke: `examples/smoke/`; sketch: `examples/ota_http/`

## Out of scope

- Bringing up Wi‑Fi / DHCP (→ [137](137-gd32v-wifi-sdk.md))  
- MQTT (→ [105](105-later-tracks-iot.md) I1)  
- BLE DFU (`app_dfu_srv` / Courier)  
- Secure-boot policy / certificate provisioning (AN260 MBL verifies after reboot)  
- Hidden Klin CA store / `VERIFY_NONE` as the only Klin default for PEM path — PEM path requires caller cert  
- Changing the Klin compiler  

## Contract (prime rule)

- No Klin GC / hidden heap — image bytes are streamed from caller buffers / HTTP into flash.  
- Flash erase/write and reboot are **explicit** API steps.  
- TLS PEM is an argument (same rule as [144](144-gd32v-http-sdk.md)).  
- Errors → `-1`; success → `0` or byte counts.

## Usage (after Wi‑Fi IP)

```klin
import "github/klin-lang/gd32v_wifi" wifi
import "github/klin-lang/gd32v_ota" ota

fn main() {
    let mut e = wifi.sta_init()
    e = wifi.sta_connect("myssid", "mypass")
    e = wifi.sta_wait_ip(20000)
    if e != wifi.err_ok() {
        return
    }
    e = ota.begin()
    if e != ota.err_ok() {
        return
    }
    let n = ota.download_http("http://192.168.1.10/image-ota.bin")
    if n < 0 {
        let _a = ota.abort()
        return
    }
    e = ota.finish()
    if e != ota.err_ok() {
        return
    }
    ota.reboot()
}
```

```sh
klin get github/klin-lang/gd32v_ota@v0.1.0
```

## Links

- Repo: https://github.com/klin-lang/gd32v_ota  
- Tag: [v0.1.0](https://github.com/klin-lang/gd32v_ota/releases/tag/v0.1.0)  
- HTTP: [144](144-gd32v-http-sdk.md)  
- Wi‑Fi: [137](137-gd32v-wifi-sdk.md)  
- IoT backlog: [105](105-later-tracks-iot.md)  
- Vendor: AN260 + SDK `MSDK/app/ota_demo.c`  
