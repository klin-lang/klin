/* Host stubs for emit-c smoke (no ESP-IDF). */
#include "bus_idf.h"

int klin_rlcd_bus_init(void)
{
    return 0;
}

void klin_rlcd_wire_cmd(void *ctx, int32_t b)
{
    (void)ctx;
    (void)b;
}

void klin_rlcd_wire_data(void *ctx, int32_t b)
{
    (void)ctx;
    (void)b;
}

void klin_rlcd_wire_data_n(void *ctx, uint8_t *p, int32_t n)
{
    (void)ctx;
    (void)p;
    (void)n;
}

void klin_rlcd_wire_delay_ms(void *ctx, int32_t ms)
{
    (void)ctx;
    (void)ms;
}

void klin_rlcd_wire_rst(void *ctx)
{
    (void)ctx;
}

int klin_rlcd_battery_adc_raw(void)
{
    return 0;
}

int klin_rlcd_battery_mv(void)
{
    return 0;
}
