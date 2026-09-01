/* ESP-IDF I2C master for Waveshare ESP32-S3-RLCD-4.2 (SDA=13, SCL=14).
 * Thin bus only — SHTC3 / PCF85063 / audio codecs attach later via addr + buffers.
 */
#include "i2c_idf.h"

#include <string.h>

#include "driver/i2c_master.h"
#include "esp_err.h"

#define I2C_SDA 13
#define I2C_SCL 14
#define I2C_PORT I2C_NUM_0
#define I2C_HZ   100000
#define I2C_TIMEOUT_MS 1000

static i2c_master_bus_handle_t s_bus;
static int s_ready;

static int open_dev(int32_t addr7, i2c_master_dev_handle_t *out)
{
    i2c_device_config_t cfg;

    if (!s_ready || s_bus == NULL) {
        return -1;
    }
    if (addr7 < 0 || addr7 > 0x7f || out == NULL) {
        return -2;
    }
    memset(&cfg, 0, sizeof(cfg));
    cfg.dev_addr_length = I2C_ADDR_BIT_LEN_7;
    cfg.device_address = (uint16_t)addr7;
    cfg.scl_speed_hz = I2C_HZ;
    return (int)i2c_master_bus_add_device(s_bus, &cfg, out);
}

int klin_rlcd_i2c_init(void)
{
    esp_err_t err;
    i2c_master_bus_config_t bus_cfg;

    if (s_ready) {
        return 0;
    }

    memset(&bus_cfg, 0, sizeof(bus_cfg));
    bus_cfg.i2c_port = I2C_PORT;
    bus_cfg.sda_io_num = I2C_SDA;
    bus_cfg.scl_io_num = I2C_SCL;
    bus_cfg.clk_source = I2C_CLK_SRC_DEFAULT;
    bus_cfg.glitch_ignore_cnt = 7;
    bus_cfg.flags.enable_internal_pullup = true;

    err = i2c_new_master_bus(&bus_cfg, &s_bus);
    if (err != ESP_OK) {
        s_bus = NULL;
        return (int)err;
    }
    s_ready = 1;
    return 0;
}

int klin_rlcd_i2c_deinit(void)
{
    esp_err_t err;

    if (!s_ready) {
        return 0;
    }
    err = i2c_del_master_bus(s_bus);
    s_bus = NULL;
    s_ready = 0;
    return (int)err;
}

int klin_rlcd_i2c_ready(void)
{
    return (s_ready && s_bus != NULL) ? 1 : 0;
}

int klin_rlcd_i2c_probe(int32_t addr7)
{
    esp_err_t err;

    if (!klin_rlcd_i2c_ready()) {
        return 0;
    }
    if (addr7 < 0 || addr7 > 0x7f) {
        return 0;
    }
    err = i2c_master_probe(s_bus, (uint16_t)addr7, I2C_TIMEOUT_MS);
    return (err == ESP_OK) ? 1 : 0;
}

int klin_rlcd_i2c_write(int32_t addr7, const uint8_t *data, int32_t len)
{
    i2c_master_dev_handle_t dev;
    esp_err_t err;
    int open_err;

    if (data == NULL || len < 0) {
        return -2;
    }
    if (len == 0) {
        return 0;
    }
    open_err = open_dev(addr7, &dev);
    if (open_err != 0) {
        return open_err;
    }
    err = i2c_master_transmit(dev, data, (size_t)len, I2C_TIMEOUT_MS);
    (void)i2c_master_bus_rm_device(dev);
    return (int)err;
}

int klin_rlcd_i2c_read(int32_t addr7, uint8_t *buf, int32_t len)
{
    i2c_master_dev_handle_t dev;
    esp_err_t err;
    int open_err;

    if (buf == NULL || len <= 0) {
        return -2;
    }
    open_err = open_dev(addr7, &dev);
    if (open_err != 0) {
        return open_err;
    }
    err = i2c_master_receive(dev, buf, (size_t)len, I2C_TIMEOUT_MS);
    (void)i2c_master_bus_rm_device(dev);
    return (int)err;
}

int klin_rlcd_i2c_write_read(int32_t addr7, const uint8_t *wdata, int32_t wlen,
                             uint8_t *rbuf, int32_t rlen)
{
    i2c_master_dev_handle_t dev;
    esp_err_t err;
    int open_err;

    if (wdata == NULL || wlen < 0 || rbuf == NULL || rlen <= 0) {
        return -2;
    }
    if (wlen == 0) {
        return klin_rlcd_i2c_read(addr7, rbuf, rlen);
    }
    open_err = open_dev(addr7, &dev);
    if (open_err != 0) {
        return open_err;
    }
    err = i2c_master_transmit_receive(dev, wdata, (size_t)wlen, rbuf,
                                      (size_t)rlen, I2C_TIMEOUT_MS);
    (void)i2c_master_bus_rm_device(dev);
    return (int)err;
}
