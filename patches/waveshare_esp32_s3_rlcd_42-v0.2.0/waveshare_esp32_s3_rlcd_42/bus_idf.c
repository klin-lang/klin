/* ESP-IDF SPI/GPIO/ADC bus for Waveshare ESP32-S3-RLCD-4.2.
 * Panel init + FB packing live in klin_st7305 (Wire). This file only owns the bus.
 */
#include "bus_idf.h"

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
#define FB_BYTES    15000

static spi_device_handle_t s_spi;
static int s_bus_ready;
static adc_oneshot_unit_handle_t s_adc;
static int s_adc_ready;

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

int klin_rlcd_bus_init(void)
{
    esp_err_t err;
    gpio_config_t io;
    spi_bus_config_t bus;
    spi_device_interface_config_t dev;

    if (s_bus_ready) {
        return (int)ESP_OK;
    }

    memset(&io, 0, sizeof(io));
    io.pin_bit_mask = (1ULL << PIN_DC) | (1ULL << PIN_RST);
    io.mode = GPIO_MODE_OUTPUT;
    err = gpio_config(&io);
    if (err != ESP_OK) {
        return (int)err;
    }

    dc_set(1);
    rst_set(1);

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

    s_bus_ready = 1;
    return (int)ESP_OK;
}

void klin_rlcd_wire_cmd(void *ctx, int32_t b)
{
    (void)ctx;
    if (!s_bus_ready) {
        return;
    }
    dc_set(0);
    spi_write_byte((uint8_t)(b & 255));
    dc_set(1);
}

void klin_rlcd_wire_data(void *ctx, int32_t b)
{
    (void)ctx;
    if (!s_bus_ready) {
        return;
    }
    dc_set(1);
    spi_write_byte((uint8_t)(b & 255));
}

void klin_rlcd_wire_data_n(void *ctx, uint8_t *p, int32_t n)
{
    spi_transaction_t t;

    (void)ctx;
    if (!s_bus_ready || p == NULL || n <= 0) {
        return;
    }
    dc_set(1);
    memset(&t, 0, sizeof(t));
    t.length = (size_t)n * 8;
    t.tx_buffer = p;
    spi_device_polling_transmit(s_spi, &t);
}

void klin_rlcd_wire_delay_ms(void *ctx, int32_t ms)
{
    (void)ctx;
    if (ms > 0) {
        vTaskDelay(pdMS_TO_TICKS((uint32_t)ms));
    }
}

void klin_rlcd_wire_rst(void *ctx)
{
    (void)ctx;
    rst_set(1);
    vTaskDelay(pdMS_TO_TICKS(50));
    rst_set(0);
    vTaskDelay(pdMS_TO_TICKS(20));
    rst_set(1);
    vTaskDelay(pdMS_TO_TICKS(50));
    dc_set(1);
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
    return (raw * 3300 * 3) / 4095;
}
