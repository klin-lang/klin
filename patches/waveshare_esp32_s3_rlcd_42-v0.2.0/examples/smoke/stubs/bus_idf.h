#pragma once
#include <stdint.h>

int klin_rlcd_bus_init(void);
void klin_rlcd_wire_cmd(void *ctx, int32_t b);
void klin_rlcd_wire_data(void *ctx, int32_t b);
void klin_rlcd_wire_data_n(void *ctx, uint8_t *p, int32_t n);
void klin_rlcd_wire_delay_ms(void *ctx, int32_t ms);
void klin_rlcd_wire_rst(void *ctx);
int klin_rlcd_battery_adc_raw(void);
int klin_rlcd_battery_mv(void);
