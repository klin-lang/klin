/* ESP-IDF I2S + ES8311 (DAC) + ES7210 (ADC) for Waveshare ESP32-S3-RLCD-4.2.
 * Pins: MCLK=16 BCLK=9 WS=45 DOUT=8 DIN=10 PA=46; I2C ES8311=0x18 ES7210=0x40.
 * Sample rates: 16000 (MCLK×256), 24000 (MCLK×512), 48000 (MCLK×256).
 * No heap for PCM — caller owns buffers. Uses board I2C master helpers.
 */
#include "audio_idf.h"

#include "i2c_idf.h"

#include <string.h>

#include "driver/gpio.h"
#include "driver/i2s_std.h"
#include "esp_err.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

#define I2S_MCLK 16
#define I2S_BCLK 9
#define I2S_WS   45
#define I2S_DOUT 8
#define I2S_DIN  10
#define PA_GPIO  46

#define ES8311_ADDR 0x18
#define ES7210_ADDR 0x40

#define I2S_TIMEOUT_MS 1000

typedef struct {
    uint32_t mclk;
    uint32_t rate;
    uint8_t pre_div;
    uint8_t pre_multi;
    uint8_t adc_div;
    uint8_t dac_div;
    uint8_t fs_mode;
    uint8_t lrck_h;
    uint8_t lrck_l;
    uint8_t bclk_div;
    uint8_t adc_osr;
    uint8_t dac_osr;
    int mclk_multiple; /* I2S_MCLK_MULTIPLE_* numeric value */
} es8311_coeff_t;

typedef struct {
    uint32_t mclk;
    uint32_t rate;
    uint8_t adc_div;
    uint8_t dll;
    uint8_t doubler;
    uint8_t osr;
    uint8_t lrck_h;
    uint8_t lrck_l;
} es7210_coeff_t;

/* Coeff rows from Espressif esp-bsp es8311/es7210 (Apache-2.0), trimmed. */
static const es8311_coeff_t s_es8311_coeffs[] = {
    /* 16k @ 4.096 MHz (×256) */
    {4096000, 16000, 0x01, 0x00, 0x01, 0x01, 0x00, 0x00, 0xff, 0x04, 0x10, 0x10, 256},
    /* 24k @ 12.288 MHz (×512) */
    {12288000, 24000, 0x02, 0x00, 0x01, 0x01, 0x00, 0x00, 0xff, 0x04, 0x10, 0x10, 512},
    /* 48k @ 12.288 MHz (×256) */
    {12288000, 48000, 0x01, 0x00, 0x01, 0x01, 0x00, 0x00, 0xff, 0x04, 0x10, 0x10, 256},
};

static const es7210_coeff_t s_es7210_coeffs[] = {
    {4096000, 16000, 0x01, 0x01, 0x01, 0x20, 0x01, 0x00},
    {12288000, 24000, 0x01, 0x01, 0x00, 0x20, 0x02, 0x00},
    {12288000, 48000, 0x01, 0x01, 0x01, 0x20, 0x01, 0x00},
};

static i2s_chan_handle_t s_tx;
static i2s_chan_handle_t s_rx;
static int s_ready;
static int32_t s_rate;

static int i2c_w(uint8_t addr, uint8_t reg, uint8_t val)
{
    uint8_t buf[2];

    buf[0] = reg;
    buf[1] = val;
    return klin_rlcd_i2c_write((int32_t)addr, buf, 2);
}

static int i2c_r(uint8_t addr, uint8_t reg, uint8_t *val)
{
    return klin_rlcd_i2c_write_read((int32_t)addr, &reg, 1, val, 1);
}

static const es8311_coeff_t *find_es8311(int32_t rate)
{
    size_t i;

    for (i = 0; i < sizeof(s_es8311_coeffs) / sizeof(s_es8311_coeffs[0]); i++) {
        if ((int32_t)s_es8311_coeffs[i].rate == rate) {
            return &s_es8311_coeffs[i];
        }
    }
    return NULL;
}

static const es7210_coeff_t *find_es7210(int32_t rate)
{
    size_t i;

    for (i = 0; i < sizeof(s_es7210_coeffs) / sizeof(s_es7210_coeffs[0]); i++) {
        if ((int32_t)s_es7210_coeffs[i].rate == rate) {
            return &s_es7210_coeffs[i];
        }
    }
    return NULL;
}

static int es8311_bringup(const es8311_coeff_t *c)
{
    uint8_t regv;
    int err;

    err = i2c_w(ES8311_ADDR, 0x00, 0x1F);
    if (err != 0) {
        return err;
    }
    vTaskDelay(pdMS_TO_TICKS(20));
    err = i2c_w(ES8311_ADDR, 0x00, 0x00);
    if (err != 0) {
        return err;
    }
    err = i2c_w(ES8311_ADDR, 0x00, 0x80);
    if (err != 0) {
        return err;
    }

    /* REG01: all clocks from MCLK pin */
    err = i2c_w(ES8311_ADDR, 0x01, 0x3F);
    if (err != 0) {
        return err;
    }

    err = i2c_r(ES8311_ADDR, 0x02, &regv);
    if (err != 0) {
        return err;
    }
    regv &= 0x07;
    regv |= (uint8_t)((c->pre_div - 1) << 5);
    regv |= (uint8_t)(c->pre_multi << 3);
    err = i2c_w(ES8311_ADDR, 0x02, regv);
    if (err != 0) {
        return err;
    }

    err = i2c_w(ES8311_ADDR, 0x03, (uint8_t)((c->fs_mode << 6) | c->adc_osr));
    if (err != 0) {
        return err;
    }
    err = i2c_w(ES8311_ADDR, 0x04, c->dac_osr);
    if (err != 0) {
        return err;
    }
    err = i2c_w(ES8311_ADDR, 0x05,
                (uint8_t)(((c->adc_div - 1) << 4) | (c->dac_div - 1)));
    if (err != 0) {
        return err;
    }

    err = i2c_r(ES8311_ADDR, 0x06, &regv);
    if (err != 0) {
        return err;
    }
    regv &= 0xE0;
    if (c->bclk_div < 19) {
        regv |= (uint8_t)(c->bclk_div - 1);
    } else {
        regv |= c->bclk_div;
    }
    err = i2c_w(ES8311_ADDR, 0x06, regv);
    if (err != 0) {
        return err;
    }

    err = i2c_r(ES8311_ADDR, 0x07, &regv);
    if (err != 0) {
        return err;
    }
    regv &= 0xC0;
    regv |= c->lrck_h;
    err = i2c_w(ES8311_ADDR, 0x07, regv);
    if (err != 0) {
        return err;
    }
    err = i2c_w(ES8311_ADDR, 0x08, c->lrck_l);
    if (err != 0) {
        return err;
    }

    /* Slave, I2S, 16-bit in/out (res bits = 3 << 2) */
    err = i2c_r(ES8311_ADDR, 0x00, &regv);
    if (err != 0) {
        return err;
    }
    regv &= 0xBF;
    err = i2c_w(ES8311_ADDR, 0x00, regv);
    if (err != 0) {
        return err;
    }
    err = i2c_w(ES8311_ADDR, 0x09, 0x0C);
    if (err != 0) {
        return err;
    }
    err = i2c_w(ES8311_ADDR, 0x0A, 0x0C);
    if (err != 0) {
        return err;
    }

    err = i2c_w(ES8311_ADDR, 0x0D, 0x01);
    if (err != 0) {
        return err;
    }
    err = i2c_w(ES8311_ADDR, 0x0E, 0x02);
    if (err != 0) {
        return err;
    }
    err = i2c_w(ES8311_ADDR, 0x12, 0x00);
    if (err != 0) {
        return err;
    }
    err = i2c_w(ES8311_ADDR, 0x13, 0x10);
    if (err != 0) {
        return err;
    }
    err = i2c_w(ES8311_ADDR, 0x1C, 0x6A);
    if (err != 0) {
        return err;
    }
    err = i2c_w(ES8311_ADDR, 0x37, 0x08);
    if (err != 0) {
        return err;
    }

    /* Default volume ~80 */
    return i2c_w(ES8311_ADDR, 0x32, (uint8_t)((80 * 256 / 100) - 1));
}

static int es7210_bringup(const es7210_coeff_t *c)
{
    int err;

    err = i2c_w(ES7210_ADDR, 0x00, 0xFF);
    if (err != 0) {
        return err;
    }
    err = i2c_w(ES7210_ADDR, 0x00, 0x32);
    if (err != 0) {
        return err;
    }
    err = i2c_w(ES7210_ADDR, 0x09, 0x30);
    if (err != 0) {
        return err;
    }
    err = i2c_w(ES7210_ADDR, 0x0A, 0x30);
    if (err != 0) {
        return err;
    }
    err = i2c_w(ES7210_ADDR, 0x23, 0x2A);
    if (err != 0) {
        return err;
    }
    err = i2c_w(ES7210_ADDR, 0x22, 0x0A);
    if (err != 0) {
        return err;
    }
    err = i2c_w(ES7210_ADDR, 0x21, 0x2A);
    if (err != 0) {
        return err;
    }
    err = i2c_w(ES7210_ADDR, 0x20, 0x0A);
    if (err != 0) {
        return err;
    }

    /* I2S + 16-bit, no TDM */
    err = i2c_w(ES7210_ADDR, 0x11, 0x60);
    if (err != 0) {
        return err;
    }
    err = i2c_w(ES7210_ADDR, 0x12, 0x00);
    if (err != 0) {
        return err;
    }

    err = i2c_w(ES7210_ADDR, 0x40, 0xC3);
    if (err != 0) {
        return err;
    }
    /* Mic bias 2.87V */
    err = i2c_w(ES7210_ADDR, 0x41, 0x70);
    if (err != 0) {
        return err;
    }
    err = i2c_w(ES7210_ADDR, 0x42, 0x70);
    if (err != 0) {
        return err;
    }
    /* Mic gain ~30 dB (| 0x10) */
    err = i2c_w(ES7210_ADDR, 0x43, 0x1A);
    if (err != 0) {
        return err;
    }
    err = i2c_w(ES7210_ADDR, 0x44, 0x1A);
    if (err != 0) {
        return err;
    }
    err = i2c_w(ES7210_ADDR, 0x45, 0x1A);
    if (err != 0) {
        return err;
    }
    err = i2c_w(ES7210_ADDR, 0x46, 0x1A);
    if (err != 0) {
        return err;
    }

    err = i2c_w(ES7210_ADDR, 0x47, 0x08);
    if (err != 0) {
        return err;
    }
    err = i2c_w(ES7210_ADDR, 0x48, 0x08);
    if (err != 0) {
        return err;
    }
    err = i2c_w(ES7210_ADDR, 0x49, 0x08);
    if (err != 0) {
        return err;
    }
    err = i2c_w(ES7210_ADDR, 0x4A, 0x08);
    if (err != 0) {
        return err;
    }

    err = i2c_w(ES7210_ADDR, 0x07, c->osr);
    if (err != 0) {
        return err;
    }
    err = i2c_w(ES7210_ADDR, 0x02,
                (uint8_t)(c->adc_div | (c->doubler << 6) | (c->dll << 7)));
    if (err != 0) {
        return err;
    }
    err = i2c_w(ES7210_ADDR, 0x04, c->lrck_h);
    if (err != 0) {
        return err;
    }
    err = i2c_w(ES7210_ADDR, 0x05, c->lrck_l);
    if (err != 0) {
        return err;
    }

    err = i2c_w(ES7210_ADDR, 0x06, 0x04);
    if (err != 0) {
        return err;
    }
    err = i2c_w(ES7210_ADDR, 0x4B, 0x0F);
    if (err != 0) {
        return err;
    }
    err = i2c_w(ES7210_ADDR, 0x4C, 0x0F);
    if (err != 0) {
        return err;
    }
    err = i2c_w(ES7210_ADDR, 0x00, 0x71);
    if (err != 0) {
        return err;
    }
    return i2c_w(ES7210_ADDR, 0x00, 0x41);
}

static int i2s_bringup(int32_t rate, int mclk_multiple)
{
    esp_err_t err;
    i2s_chan_config_t chan_cfg = I2S_CHANNEL_DEFAULT_CONFIG(I2S_NUM_0, I2S_ROLE_MASTER);
    i2s_std_config_t std_cfg;
    i2s_mclk_multiple_t mclk_mul;

    chan_cfg.auto_clear = true;

    if (mclk_multiple == 512) {
        mclk_mul = I2S_MCLK_MULTIPLE_512;
    } else {
        mclk_mul = I2S_MCLK_MULTIPLE_256;
    }

    err = i2s_new_channel(&chan_cfg, &s_tx, &s_rx);
    if (err != ESP_OK) {
        s_tx = NULL;
        s_rx = NULL;
        return (int)err;
    }

    memset(&std_cfg, 0, sizeof(std_cfg));
    std_cfg.clk_cfg = (i2s_std_clk_config_t)I2S_STD_CLK_DEFAULT_CONFIG((uint32_t)rate);
    std_cfg.clk_cfg.mclk_multiple = mclk_mul;
    std_cfg.slot_cfg = (i2s_std_slot_config_t)I2S_STD_PHILIPS_SLOT_DEFAULT_CONFIG(
        I2S_DATA_BIT_WIDTH_16BIT, I2S_SLOT_MODE_STEREO);
    std_cfg.gpio_cfg.mclk = I2S_MCLK;
    std_cfg.gpio_cfg.bclk = I2S_BCLK;
    std_cfg.gpio_cfg.ws = I2S_WS;
    std_cfg.gpio_cfg.dout = I2S_DOUT;
    std_cfg.gpio_cfg.din = I2S_DIN;
    std_cfg.gpio_cfg.invert_flags.mclk_inv = false;
    std_cfg.gpio_cfg.invert_flags.bclk_inv = false;
    std_cfg.gpio_cfg.invert_flags.ws_inv = false;

    err = i2s_channel_init_std_mode(s_tx, &std_cfg);
    if (err != ESP_OK) {
        return (int)err;
    }
    err = i2s_channel_init_std_mode(s_rx, &std_cfg);
    if (err != ESP_OK) {
        return (int)err;
    }
    err = i2s_channel_enable(s_tx);
    if (err != ESP_OK) {
        return (int)err;
    }
    err = i2s_channel_enable(s_rx);
    if (err != ESP_OK) {
        return (int)err;
    }
    return 0;
}

static int pa_gpio_init(void)
{
    gpio_config_t cfg;

    memset(&cfg, 0, sizeof(cfg));
    cfg.pin_bit_mask = 1ULL << PA_GPIO;
    cfg.mode = GPIO_MODE_OUTPUT;
    cfg.pull_up_en = GPIO_PULLUP_DISABLE;
    cfg.pull_down_en = GPIO_PULLDOWN_DISABLE;
    cfg.intr_type = GPIO_INTR_DISABLE;
    return (int)gpio_config(&cfg);
}

int klin_rlcd_audio_init(int32_t sample_rate)
{
    const es8311_coeff_t *c8311;
    const es7210_coeff_t *c7210;
    int err;

    if (s_ready) {
        return 0;
    }

    c8311 = find_es8311(sample_rate);
    c7210 = find_es7210(sample_rate);
    if (c8311 == NULL || c7210 == NULL) {
        return -2;
    }

    err = klin_rlcd_i2c_init();
    if (err != 0) {
        return err;
    }

    err = pa_gpio_init();
    if (err != 0) {
        return err;
    }
    gpio_set_level(PA_GPIO, 0);

    err = i2s_bringup(sample_rate, c8311->mclk_multiple);
    if (err != 0) {
        (void)klin_rlcd_audio_deinit();
        return err;
    }

    err = es8311_bringup(c8311);
    if (err != 0) {
        (void)klin_rlcd_audio_deinit();
        return err;
    }
    err = es7210_bringup(c7210);
    if (err != 0) {
        (void)klin_rlcd_audio_deinit();
        return err;
    }

    /* Amp on after codecs ready */
    gpio_set_level(PA_GPIO, 1);
    s_rate = sample_rate;
    s_ready = 1;
    return 0;
}

int klin_rlcd_audio_deinit(void)
{
    esp_err_t err = ESP_OK;

    gpio_set_level(PA_GPIO, 0);

    if (s_tx != NULL) {
        (void)i2s_channel_disable(s_tx);
    }
    if (s_rx != NULL) {
        (void)i2s_channel_disable(s_rx);
    }
    if (s_tx != NULL) {
        err = i2s_del_channel(s_tx);
        s_tx = NULL;
    }
    if (s_rx != NULL) {
        esp_err_t err2 = i2s_del_channel(s_rx);
        if (err == ESP_OK) {
            err = err2;
        }
        s_rx = NULL;
    }
    s_ready = 0;
    s_rate = 0;
    return (int)err;
}

int klin_rlcd_audio_ready(void)
{
    return (s_ready && s_tx != NULL && s_rx != NULL) ? 1 : 0;
}

int klin_rlcd_audio_pa_enable(int32_t on)
{
    if (!s_ready) {
        return -1;
    }
    return (int)gpio_set_level(PA_GPIO, on ? 1 : 0);
}

int klin_rlcd_audio_set_volume(int32_t vol)
{
    int reg32;

    if (!s_ready) {
        return -1;
    }
    if (vol < 0) {
        vol = 0;
    } else if (vol > 100) {
        vol = 100;
    }
    if (vol == 0) {
        reg32 = 0;
    } else {
        reg32 = (vol * 256 / 100) - 1;
    }
    return i2c_w(ES8311_ADDR, 0x32, (uint8_t)reg32);
}

int klin_rlcd_audio_write(const uint8_t *pcm, int32_t len)
{
    size_t written = 0;
    esp_err_t err;

    if (!s_ready || s_tx == NULL) {
        return -1;
    }
    if (pcm == NULL || len < 0) {
        return -2;
    }
    if (len == 0) {
        return 0;
    }
    err = i2s_channel_write(s_tx, pcm, (size_t)len, &written,
                            pdMS_TO_TICKS(I2S_TIMEOUT_MS));
    if (err != ESP_OK) {
        return (int)err;
    }
    if ((int32_t)written != len) {
        return -3;
    }
    return 0;
}

int klin_rlcd_audio_read(uint8_t *buf, int32_t max)
{
    size_t got = 0;
    esp_err_t err;

    if (!s_ready || s_rx == NULL) {
        return -1;
    }
    if (buf == NULL || max <= 0) {
        return -2;
    }
    err = i2s_channel_read(s_rx, buf, (size_t)max, &got,
                           pdMS_TO_TICKS(I2S_TIMEOUT_MS));
    if (err != ESP_OK) {
        return (int)err;
    }
    return (int)got;
}
