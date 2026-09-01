#include "i2c_idf.h"
#include <string.h>

static uint8_t rtc_mem[16];

int klin_rlcd_i2c_init(void) { return 0; }
int klin_rlcd_i2c_deinit(void) { return 0; }
int klin_rlcd_i2c_ready(void) { return 1; }
int klin_rlcd_i2c_probe(int32_t addr7)
{
    (void)addr7;
    return 1;
}
int klin_rlcd_i2c_write(int32_t addr7, const uint8_t *data, int32_t len)
{
    if (addr7 == 0x51 && data != NULL && len >= 1) {
        int reg = (int)data[0];
        for (int i = 1; i < len; i++) {
            int idx = reg + i - 1;
            if (idx >= 0 && idx < 16) {
                rtc_mem[idx] = data[i];
            }
        }
    }
    (void)addr7; (void)data; (void)len;
    return 0;
}
int klin_rlcd_i2c_read(int32_t addr7, uint8_t *buf, int32_t len)
{
    /* SHTC3 fixture: raw_t=0x6666 crc=0x93, raw_rh=0x8000 crc=0xA2 */
    static const uint8_t shtc3_sample[6] = {0x66, 0x66, 0x93, 0x80, 0x00, 0xA2};
    if (addr7 == 0x70 && buf != NULL && len > 0) {
        int n = len < 6 ? len : 6;
        memcpy(buf, shtc3_sample, (size_t)n);
        return 0;
    }
    (void)addr7; (void)buf; (void)len;
    return 0;
}
int klin_rlcd_i2c_write_read(int32_t addr7, const uint8_t *wdata, int32_t wlen,
                             uint8_t *rbuf, int32_t rlen)
{
    if (addr7 == 0x51 && wdata != NULL && wlen >= 1 && rbuf != NULL && rlen > 0) {
        int reg = (int)wdata[0];
        for (int i = 0; i < rlen; i++) {
            int idx = reg + i;
            rbuf[i] = (idx >= 0 && idx < 16) ? rtc_mem[idx] : 0;
        }
        return 0;
    }
    (void)addr7; (void)wdata; (void)wlen; (void)rbuf; (void)rlen;
    return 0;
}
