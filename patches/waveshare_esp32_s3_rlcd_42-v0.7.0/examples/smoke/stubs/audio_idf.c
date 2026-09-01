#include "audio_idf.h"
#include <string.h>

static int s_ready;
static int s_vol = 80;

int klin_rlcd_audio_init(int32_t sample_rate)
{
    if (sample_rate != 16000 && sample_rate != 24000 && sample_rate != 48000) {
        return -2;
    }
    s_ready = 1;
    s_vol = 80;
    return 0;
}

int klin_rlcd_audio_deinit(void)
{
    s_ready = 0;
    return 0;
}

int klin_rlcd_audio_ready(void)
{
    return s_ready ? 1 : 0;
}

int klin_rlcd_audio_pa_enable(int32_t on)
{
    if (!s_ready) {
        return -1;
    }
    (void)on;
    return 0;
}

int klin_rlcd_audio_set_volume(int32_t vol)
{
    if (!s_ready) {
        return -1;
    }
    if (vol < 0) {
        vol = 0;
    } else if (vol > 100) {
        vol = 100;
    }
    s_vol = (int)vol;
    return 0;
}

int klin_rlcd_audio_write(const uint8_t *pcm, int32_t len)
{
    if (!s_ready) {
        return -1;
    }
    if (pcm == NULL || len < 0) {
        return -2;
    }
    (void)pcm;
    return 0;
}

int klin_rlcd_audio_read(uint8_t *buf, int32_t max)
{
    if (!s_ready) {
        return -1;
    }
    if (buf == NULL || max <= 0) {
        return -2;
    }
    memset(buf, 0, (size_t)max);
    return max;
}
