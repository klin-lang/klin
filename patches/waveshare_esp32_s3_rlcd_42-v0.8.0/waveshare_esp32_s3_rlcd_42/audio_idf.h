/* Audio (ES8311 out + ES7210 in) — Waveshare ESP32-S3-RLCD-4.2, ESP-IDF v5.x.
 * I2S: MCLK=16 BCLK=9 WS=45 DOUT=8 DIN=10; PA=46; codecs on shared I2C.
 */
#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/** Bring up I2C (if needed), PA GPIO, I2S duplex, ES8311 + ES7210.
 *  `sample_rate`: 16000, 24000, or 48000. Returns 0 = OK. */
int klin_rlcd_audio_init(int32_t sample_rate);

/** Tear down I2S + PA off. Codecs left powered; I2C bus stays up. */
int klin_rlcd_audio_deinit(void);

/** 1 after successful `klin_rlcd_audio_init`. */
int klin_rlcd_audio_ready(void);

/** Speaker amp enable (GPIO46). `on` != 0 → high. 0 = OK. */
int klin_rlcd_audio_pa_enable(int32_t on);

/** ES8311 DAC volume 0..100. 0 = OK. */
int klin_rlcd_audio_set_volume(int32_t vol);

/** Write `len` PCM bytes (16-bit stereo interleaved) to I2S TX. 0 = OK. */
int klin_rlcd_audio_write(const uint8_t *pcm, int32_t len);

/** Read up to `max` PCM bytes from I2S RX. Returns byte count or <0. */
int klin_rlcd_audio_read(uint8_t *buf, int32_t max);

#ifdef __cplusplus
}
#endif
