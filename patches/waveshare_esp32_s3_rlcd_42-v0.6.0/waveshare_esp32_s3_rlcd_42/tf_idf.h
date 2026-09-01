/* TF (microSD) SDMMC helpers — Waveshare ESP32-S3-RLCD-4.2, ESP-IDF v5.x. */
#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/** Mount FAT at `/sdcard` (1-bit SDMMC: CLK=38 CMD=21 D0=39). esp_err_t as int. */
int klin_rlcd_tf_mount(void);

/** Unmount `/sdcard`. */
int klin_rlcd_tf_unmount(void);

/** 1 if mounted and card responds. */
int klin_rlcd_tf_ready(void);

/** Write `len` bytes to `path` (e.g. `/sdcard/x.bin`). 0 = OK, <0 = error. */
int klin_rlcd_tf_write(const char *path, const uint8_t *data, int32_t len);

/** Read up to `max` bytes; return byte count or <0. */
int klin_rlcd_tf_read(const char *path, uint8_t *buf, int32_t max);

#ifdef __cplusplus
}
#endif
