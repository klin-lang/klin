#include "tf_idf.h"

int klin_rlcd_tf_mount(void) { return 0; }
int klin_rlcd_tf_unmount(void) { return 0; }
int klin_rlcd_tf_ready(void) { return 1; }
int klin_rlcd_tf_write(const char *path, const uint8_t *data, int32_t len)
{
    (void)path; (void)data; (void)len;
    return 0;
}
int klin_rlcd_tf_read(const char *path, uint8_t *buf, int32_t max)
{
    (void)path; (void)buf;
    return max;
}
