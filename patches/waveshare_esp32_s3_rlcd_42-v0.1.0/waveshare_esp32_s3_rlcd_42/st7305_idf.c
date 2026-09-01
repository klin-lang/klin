/* ST7305 RLCD for Waveshare ESP32-S3-RLCD-4.2 under ESP-IDF v5.x.
 * Init sequence from Waveshare reference; FB packing matches landscape pixel.
 */
#include "st7305_idf.h"

#include <string.h>

#include "driver/gpio.h"
#include "driver/spi_master.h"
#include "esp_adc/adc_oneshot.h"
#include "esp_err.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

#define PIN_SCK  11
#define PIN_MOSI 12
#define PIN_CS   40
#define PIN_DC   5
#define PIN_RST  41
#define PIN_BAT  4

#define SPI_HOST_ID SPI2_HOST
#define SPI_MHZ     10

#define PANEL_W  400
#define PANEL_H  300
#define FB_BYTES ((PANEL_W / 2) * (PANEL_H / 4))

#define CASET_START 0x12
#define CASET_END   0x2A
#define RASET_START 0x00
#define RASET_END   0xC7

static spi_device_handle_t s_spi;
static int s_inited;
static adc_oneshot_unit_handle_t s_adc;
static int s_adc_ready;

int klin_rlcd_width(void)
{
    return PANEL_W;
}

int klin_rlcd_height(void)
{
    return PANEL_H;
}

int klin_rlcd_fb_bytes(void)
{
    return FB_BYTES;
}

static void dc_set(int level)
{
    gpio_set_level(PIN_DC, level);
}

static void rst_set(int level)
{
    gpio_set_level(PIN_RST, level);
}

static void spi_write_byte(uint8_t byte)
{
    spi_transaction_t t = {
        .length = 8,
        .tx_buffer = &byte,
    };
    spi_device_polling_transmit(s_spi, &t);
}

static void send_cmd(uint8_t cmd)
{
    dc_set(0);
    spi_write_byte(cmd);
    dc_set(1);
}

static void send_data(const uint8_t *data, size_t len)
{
    spi_transaction_t t;

    if (len == 0) {
        return;
    }
    memset(&t, 0, sizeof(t));
    t.length = (size_t)len * 8;
    t.tx_buffer = data;
    spi_device_polling_transmit(s_spi, &t);
}

static void send_data_byte(uint8_t d)
{
    send_data(&d, 1);
}

static void st7305_panel_init(void)
{
    send_cmd(0xD6);
    {
        uint8_t d[] = {0x17, 0x02};
        send_data(d, 2);
    }
    send_cmd(0xD1);
    send_data_byte(0x01);

    send_cmd(0xC0);
    {
        uint8_t d[] = {0x11, 0x04};
        send_data(d, 2);
    }
    send_cmd(0xC1);
    {
        uint8_t d[] = {0x41, 0x41, 0x41, 0x41};
        send_data(d, 4);
    }
    send_cmd(0xC2);
    {
        uint8_t d[] = {0x19, 0x19, 0x19, 0x19};
        send_data(d, 4);
    }
    send_cmd(0xC4);
    {
        uint8_t d[] = {0x41, 0x41, 0x41, 0x41};
        send_data(d, 4);
    }
    send_cmd(0xC5);
    {
        uint8_t d[] = {0x19, 0x19, 0x19, 0x19};
        send_data(d, 4);
    }

    send_cmd(0xD8);
    {
        uint8_t d[] = {0xA6, 0xE9};
        send_data(d, 2);
    }

    send_cmd(0xB2);
    send_data_byte(0x05);
    send_cmd(0xB3);
    {
        uint8_t d[] = {0xE5, 0xF6, 0x05, 0x46, 0x77, 0x77, 0x77, 0x77, 0x76, 0x45};
        send_data(d, 10);
    }
    send_cmd(0xB4);
    {
        uint8_t d[] = {0x05, 0x46, 0x77, 0x77, 0x77, 0x77, 0x76, 0x45};
        send_data(d, 8);
    }
    send_cmd(0x62);
    {
        uint8_t d[] = {0x32, 0x03, 0x1F};
        send_data(d, 3);
    }

    send_cmd(0xB7);
    send_data_byte(0x13);
    send_cmd(0xB0);
    send_data_byte(0x64);

    send_cmd(0x11);
    vTaskDelay(pdMS_TO_TICKS(200));

    send_cmd(0xC9);
    send_data_byte(0x00);
    send_cmd(0x36);
    send_data_byte(0x48);
    send_cmd(0x3A);
    send_data_byte(0x11);
    send_cmd(0xB9);
    send_data_byte(0x20);
    send_cmd(0xB8);
    send_data_byte(0x29);
    send_cmd(0x21);

    send_cmd(0x2A);
    {
        uint8_t d[] = {CASET_START, CASET_END};
        send_data(d, 2);
    }
    send_cmd(0x2B);
    {
        uint8_t d[] = {RASET_START, RASET_END};
        send_data(d, 2);
    }

    send_cmd(0x35);
    send_data_byte(0x00);
    send_cmd(0xD0);
    send_data_byte(0xFF);
    send_cmd(0x38);
    send_cmd(0x29);
}

int klin_rlcd_init(void)
{
    esp_err_t err;
    gpio_config_t io;
    spi_bus_config_t bus;
    spi_device_interface_config_t dev;

    if (s_inited) {
        return (int)ESP_OK;
    }

    memset(&io, 0, sizeof(io));
    io.pin_bit_mask = (1ULL << PIN_DC) | (1ULL << PIN_RST);
    io.mode = GPIO_MODE_OUTPUT;
    err = gpio_config(&io);
    if (err != ESP_OK) {
        return (int)err;
    }

    rst_set(1);
    vTaskDelay(pdMS_TO_TICKS(50));
    rst_set(0);
    vTaskDelay(pdMS_TO_TICKS(20));
    rst_set(1);
    vTaskDelay(pdMS_TO_TICKS(50));
    dc_set(1);

    memset(&bus, 0, sizeof(bus));
    bus.mosi_io_num = PIN_MOSI;
    bus.miso_io_num = -1;
    bus.sclk_io_num = PIN_SCK;
    bus.quadwp_io_num = -1;
    bus.quadhd_io_num = -1;
    bus.max_transfer_sz = FB_BYTES + 4;
    err = spi_bus_initialize(SPI_HOST_ID, &bus, SPI_DMA_CH_AUTO);
    if (err != ESP_OK) {
        return (int)err;
    }

    memset(&dev, 0, sizeof(dev));
    dev.clock_speed_hz = SPI_MHZ * 1000 * 1000;
    dev.mode = 0;
    dev.spics_io_num = PIN_CS;
    dev.queue_size = 4;
    err = spi_bus_add_device(SPI_HOST_ID, &dev, &s_spi);
    if (err != ESP_OK) {
        return (int)err;
    }

    st7305_panel_init();
    s_inited = 1;
    return (int)ESP_OK;
}

int klin_rlcd_clear(uint8_t *fb, int len)
{
    if (fb == NULL || len != FB_BYTES) {
        return (int)ESP_ERR_INVALID_ARG;
    }
    memset(fb, 0xFF, (size_t)FB_BYTES);
    return (int)ESP_OK;
}

int klin_rlcd_fill(uint8_t *fb, int len)
{
    if (fb == NULL || len != FB_BYTES) {
        return (int)ESP_ERR_INVALID_ARG;
    }
    memset(fb, 0x00, (size_t)FB_BYTES);
    return (int)ESP_OK;
}

int klin_rlcd_set_pixel(uint8_t *fb, int len, int x, int y, int color)
{
    int inv_y;
    uint32_t idx;
    uint8_t bit;

    if (fb == NULL || len != FB_BYTES) {
        return (int)ESP_ERR_INVALID_ARG;
    }
    if (x < 0 || y < 0 || x >= PANEL_W || y >= PANEL_H) {
        return (int)ESP_ERR_INVALID_ARG;
    }

    inv_y = PANEL_H - 1 - y;
    idx = (uint32_t)(x >> 1) * (PANEL_H >> 2) + (uint32_t)(inv_y >> 2);
    bit = (uint8_t)(7u - (uint8_t)(((inv_y & 3) << 1) | (x & 1)));
    if (color != 0) {
        fb[idx] |= (uint8_t)(1u << bit);
    } else {
        fb[idx] &= (uint8_t)~(1u << bit);
    }
    return (int)ESP_OK;
}

int klin_rlcd_rect(uint8_t *fb, int len, int x0, int y0, int x1, int y1,
                   int color)
{
    int x;
    int y;
    int t;

    if (fb == NULL || len != FB_BYTES) {
        return (int)ESP_ERR_INVALID_ARG;
    }
    if (x0 > x1) {
        t = x0;
        x0 = x1;
        x1 = t;
    }
    if (y0 > y1) {
        t = y0;
        y0 = y1;
        y1 = t;
    }
    if (x0 < 0) {
        x0 = 0;
    }
    if (y0 < 0) {
        y0 = 0;
    }
    if (x1 >= PANEL_W) {
        x1 = PANEL_W - 1;
    }
    if (y1 >= PANEL_H) {
        y1 = PANEL_H - 1;
    }
    for (y = y0; y <= y1; y++) {
        for (x = x0; x <= x1; x++) {
            (void)klin_rlcd_set_pixel(fb, len, x, y, color);
        }
    }
    return (int)ESP_OK;
}

int klin_rlcd_flush(const uint8_t *fb, int len)
{
    spi_transaction_t t;
    uint8_t caset[] = {CASET_START, CASET_END};
    uint8_t raset[] = {RASET_START, RASET_END};

    if (!s_inited) {
        return (int)ESP_ERR_INVALID_STATE;
    }
    if (fb == NULL || len != FB_BYTES) {
        return (int)ESP_ERR_INVALID_ARG;
    }

    send_cmd(0x2A);
    send_data(caset, 2);
    send_cmd(0x2B);
    send_data(raset, 2);
    send_cmd(0x2C);

    memset(&t, 0, sizeof(t));
    t.length = (size_t)FB_BYTES * 8;
    t.tx_buffer = fb;
    return (int)spi_device_polling_transmit(s_spi, &t);
}

static int klin_rlcd_adc_ensure(void)
{
    esp_err_t err;
    adc_oneshot_unit_init_cfg_t ucfg;
    adc_oneshot_chan_cfg_t ccfg;

    if (s_adc_ready) {
        return (int)ESP_OK;
    }

    memset(&ucfg, 0, sizeof(ucfg));
    ucfg.unit_id = ADC_UNIT_1;
    err = adc_oneshot_new_unit(&ucfg, &s_adc);
    if (err != ESP_OK) {
        return (int)err;
    }

    memset(&ccfg, 0, sizeof(ccfg));
    ccfg.bitwidth = ADC_BITWIDTH_DEFAULT;
    ccfg.atten = ADC_ATTEN_DB_12;
    err = adc_oneshot_config_channel(s_adc, ADC_CHANNEL_3, &ccfg);
    if (err != ESP_OK) {
        return (int)err;
    }

    s_adc_ready = 1;
    (void)PIN_BAT;
    return (int)ESP_OK;
}

int klin_rlcd_battery_adc_raw(void)
{
    int raw = 0;
    esp_err_t err;

    err = (esp_err_t)klin_rlcd_adc_ensure();
    if (err != ESP_OK) {
        return -1;
    }
    /* GPIO4 on ESP32-S3 = ADC1 channel 3. */
    err = adc_oneshot_read(s_adc, ADC_CHANNEL_3, &raw);
    if (err != ESP_OK) {
        return -1;
    }
    return raw;
}

int klin_rlcd_battery_mv(void)
{
    int raw = klin_rlcd_battery_adc_raw();
    if (raw < 0) {
        return -1;
    }
    /* Approximate: full-scale 3.3 V, divider ×3, 12-bit default. */
    return (raw * 3300 * 3) / 4095;
}
