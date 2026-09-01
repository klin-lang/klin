/* ESP-IDF bus hooks for Waveshare ESP32-S3-RLCD-4.2 — SPI Wire + battery ADC.
 * Panel protocol: klin_st7305.
 */
#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/** GPIO + SPI2 device. Does not run ST7305 init. Returns esp_err_t as int. */
int klin_rlcd_bus_init(void);

void klin_rlcd_wire_cmd(void *ctx, int32_t b);
void klin_rlcd_wire_data(void *ctx, int32_t b);
void klin_rlcd_wire_data_n(void *ctx, uint8_t *p, int32_t n);
void klin_rlcd_wire_delay_ms(void *ctx, int32_t ms);
void klin_rlcd_wire_rst(void *ctx);

int klin_rlcd_battery_adc_raw(void);
int klin_rlcd_battery_mv(void);

#ifdef __cplusplus
}
#endif
