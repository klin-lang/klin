/* I2C master helpers — Waveshare ESP32-S3-RLCD-4.2, ESP-IDF v5.x.
 * Pins: SDA=13, SCL=14 (board silk). No sensor protocol here — only the bus.
 */
#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/** Create I2C master bus (100 kHz, internal pull-ups). esp_err_t as int. */
int klin_rlcd_i2c_init(void);

/** Tear down the bus. */
int klin_rlcd_i2c_deinit(void);

/** 1 if `klin_rlcd_i2c_init` succeeded. */
int klin_rlcd_i2c_ready(void);

/** Probe 7-bit `addr7`. 1 = ACK, 0 = no device / not ready. */
int klin_rlcd_i2c_probe(int32_t addr7);

/** Write `len` bytes to 7-bit `addr7`. 0 = OK; else esp_err_t / <0. */
int klin_rlcd_i2c_write(int32_t addr7, const uint8_t *data, int32_t len);

/** Read `len` bytes from 7-bit `addr7` into `buf`. 0 = OK. */
int klin_rlcd_i2c_read(int32_t addr7, uint8_t *buf, int32_t len);

/** Write then read (restart) — typical register access. 0 = OK. */
int klin_rlcd_i2c_write_read(int32_t addr7, const uint8_t *wdata, int32_t wlen,
                             uint8_t *rbuf, int32_t rlen);

#ifdef __cplusplus
}
#endif
