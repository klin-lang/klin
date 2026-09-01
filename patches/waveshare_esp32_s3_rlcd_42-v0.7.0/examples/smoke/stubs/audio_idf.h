#pragma once
#include <stdint.h>

int klin_rlcd_audio_init(int32_t sample_rate);
int klin_rlcd_audio_deinit(void);
int klin_rlcd_audio_ready(void);
int klin_rlcd_audio_pa_enable(int32_t on);
int klin_rlcd_audio_set_volume(int32_t vol);
int klin_rlcd_audio_write(const uint8_t *pcm, int32_t len);
int klin_rlcd_audio_read(uint8_t *buf, int32_t max);
