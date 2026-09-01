/* ST7305 RLCD helpers for Waveshare ESP32-S3-RLCD-4.2 — ESP-IDF v5.x.
 * Caller owns the framebuffer (15000 bytes). No Klin heap.
 */
#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/** Panel geometry (landscape RAM). */
int klin_rlcd_width(void);
int klin_rlcd_height(void);
int klin_rlcd_fb_bytes(void);

/**
 * GPIO + SPI2 + Waveshare ST7305 init sequence.
 * Does not allocate a framebuffer. Returns esp_err_t as int (0 = OK).
 */
int klin_rlcd_init(void);

/** Fill caller buffer with white (0xFF). len must be fb_bytes. */
int klin_rlcd_clear(uint8_t *fb, int len);

/** Fill caller buffer with black (0x00). */
int klin_rlcd_fill(uint8_t *fb, int len);

/**
 * Set one pixel. color: 0 = black, non-zero = white.
 * Packing matches Waveshare landscape ST7305 framebuffer.
 */
int klin_rlcd_set_pixel(uint8_t *fb, int len, int x, int y, int color);

/** Filled axis-aligned rect (inclusive of edges clipped to panel). */
int klin_rlcd_rect(uint8_t *fb, int len, int x0, int y0, int x1, int y1,
                   int color);

/** Push full framebuffer to the panel (SPI). */
int klin_rlcd_flush(const uint8_t *fb, int len);

/**
 * Battery ADC on GPIO4 (÷3 divider). Returns raw 12-bit-ish count, or <0.
 * Each call configures oneshot ADC (IDF).
 */
int klin_rlcd_battery_adc_raw(void);

/**
 * Approximate battery millivolts (raw * 3300 * 3 / 4095).
 * Returns <0 on ADC failure.
 */
int klin_rlcd_battery_mv(void);

#ifdef __cplusplus
}
#endif
