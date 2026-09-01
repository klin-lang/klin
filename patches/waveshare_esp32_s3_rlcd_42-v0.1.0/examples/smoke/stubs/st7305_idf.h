#pragma once
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
int klin_rlcd_width(void);
int klin_rlcd_height(void);
int klin_rlcd_fb_bytes(void);
int klin_rlcd_init(void);
int klin_rlcd_clear(uint8_t *fb, int len);
int klin_rlcd_fill(uint8_t *fb, int len);
int klin_rlcd_set_pixel(uint8_t *fb, int len, int x, int y, int color);
int klin_rlcd_rect(uint8_t *fb, int len, int x0, int y0, int x1, int y1, int color);
int klin_rlcd_flush(const uint8_t *fb, int len);
int klin_rlcd_battery_adc_raw(void);
int klin_rlcd_battery_mv(void);
#ifdef __cplusplus
}
#endif
