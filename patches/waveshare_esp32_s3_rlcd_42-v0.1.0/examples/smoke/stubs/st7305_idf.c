#include "st7305_idf.h"
#include <string.h>

int klin_rlcd_width(void) { return 400; }
int klin_rlcd_height(void) { return 300; }
int klin_rlcd_fb_bytes(void) { return 15000; }
int klin_rlcd_init(void) { return 0; }
int klin_rlcd_clear(uint8_t *fb, int len)
{
    if (fb == NULL || len != 15000) return -1;
    memset(fb, 0xFF, 15000);
    return 0;
}
int klin_rlcd_fill(uint8_t *fb, int len)
{
    if (fb == NULL || len != 15000) return -1;
    memset(fb, 0x00, 15000);
    return 0;
}
int klin_rlcd_set_pixel(uint8_t *fb, int len, int x, int y, int color)
{
    (void)fb; (void)len; (void)x; (void)y; (void)color;
    return 0;
}
int klin_rlcd_rect(uint8_t *fb, int len, int x0, int y0, int x1, int y1, int color)
{
    (void)fb; (void)len; (void)x0; (void)y0; (void)x1; (void)y1; (void)color;
    return 0;
}
int klin_rlcd_flush(const uint8_t *fb, int len)
{
    (void)fb; (void)len;
    return 0;
}
int klin_rlcd_battery_adc_raw(void) { return 2000; }
int klin_rlcd_battery_mv(void) { return 3700; }
