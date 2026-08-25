# 150 — SD / FatFs packages (`klin_sd_spi` + `klin_fatfs`)

**Status:** ✅ MVP published  
- [`klin_sd_spi@v0.1.0`](https://github.com/klin-lang/klin_sd_spi/releases/tag/v0.1.0)  
- [`klin_fatfs@v0.1.0`](https://github.com/klin-lang/klin_fatfs/releases/tag/v0.1.0)  

**Depends on:** [061](061-micropython-machine-api.md), [021](021-c-libraries.md), [020](020-klin-libraries.md); LCD [`klin_st7735`](https://github.com/klin-lang/klin_st7735); touch [149](149-klin-xpt2046.md)

## Verdict

| Question | Answer |
|---|---|
| Fold SD into `klin_st7735` / `klin_xpt2046` / `weact-f411`? | **No** |
| One mega “TFT board” lib? | **No** |
| Where does the code live? | External: `klin_sd_spi` (SPI blocks) + `klin_fatfs` (ChaN FatFs FFI) |
| Arduino `SD.begin` / `File`? | **No** — caller-owned buffers; explicit `Wire` / `bind` |

## Packages

| Package | Role |
|---|---|
| [`klin_sd_spi`](https://github.com/klin-lang/klin_sd_spi) | SPI SD/MMC protocol — `attach` / `read_block` / `write_block` (`[]i32` low-byte sectors) |
| [`klin_fatfs`](https://github.com/klin-lang/klin_fatfs) | FatFs R0.16 via `@[link]` + `@[cimport]`; `use_ram` (host) or `bind` (sector ops) |

Filesystem sits above a block device. SPI (TFT module slot) and later SDIO are different bottoms under the same FatFs.

## Two different “SD” surfaces

| Source | Hardware | Bus | Notes |
|---|---|---|---|
| 1.8″ TFT module slot | microSD on display PCB | **SPI** + `SD_CS` | Use `klin_sd_spi` + `klin_fatfs.bind` |
| Black Pill F411 | **No slot on PCB** | **SDIO** on goldpins | Later backend; shop “SDIO” ≠ onboard slot |

## Scope (`@v0.1.0`)

- SPI SD init + single-block R/W  
- FatFs mount / open / read / write / sync / close / mkfs  
- Host RAM-disk smoke (`examples/host_ram`)  
- Wiring notes for msalamon TFT + Black Pill  

### Later

- SDIO F411 disk backend  
- LFN / exFAT / multi-volume  
- Tighter `[]u8` sector API in `klin_sd_spi` (today: `[]i32` low 8 bits)  
- Full bind example copying SPI sectors ↔ FatFs `BYTE*` on device  

## Contract (prime rule)

- No Klin GC / hidden heap for file buffers — app supplies `FATFS` / `FIL` / mkfs work / RAM disk.  
- ChaN may use its own window inside the caller `FATFS` (TINY config).  
- Keep unused SPI CS lines HIGH.

## Usage

```sh
klin get github/klin-lang/klin_sd_spi@v0.1.0
klin get github/klin-lang/klin_fatfs@v0.1.0
klin test klin_sd_spi
klin test klin_fatfs
klin run -I path/to/klin_fatfs examples/host_ram/main.kl
```

## Links

- Touch: [149](149-klin-xpt2046.md)  
- WeAct: [147](147-board-weact-f411.md)  
- FFI: [021](021-c-libraries.md)  
- `klin_st7735` G-176 (SD_CS HIGH): https://github.com/klin-lang/klin_st7735/tree/main/examples/g176_blackpill
