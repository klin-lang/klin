#include "i2c_idf.h"

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
    (void)addr7; (void)data; (void)len;
    return 0;
}
int klin_rlcd_i2c_read(int32_t addr7, uint8_t *buf, int32_t len)
{
    (void)addr7; (void)buf; (void)len;
    return 0;
}
int klin_rlcd_i2c_write_read(int32_t addr7, const uint8_t *wdata, int32_t wlen,
                             uint8_t *rbuf, int32_t rlen)
{
    (void)addr7; (void)wdata; (void)wlen; (void)rbuf; (void)rlen;
    return 0;
}
