/* ESP-IDF SDMMC (1-bit) + VFS Fat for Waveshare ESP32-S3-RLCD-4.2 TF slot.
 * Pins: CLK=38, CMD=21, D0=39. Not SPI — do not use klin_sd_spi here.
 */
#include "tf_idf.h"

#include <stdio.h>
#include <string.h>

#include "driver/sdmmc_host.h"
#include "esp_vfs_fat.h"
#include "sdmmc_cmd.h"

#define TF_CLK 38
#define TF_CMD 21
#define TF_D0  39
#define TF_WIDTH 1
#define TF_MOUNT "/sdcard"

static sdmmc_card_t *s_card;
static int s_mounted;

int klin_rlcd_tf_mount(void)
{
    esp_err_t err;
    esp_vfs_fat_sdmmc_mount_config_t mount_config = {
        .format_if_mount_failed = false,
        .max_files = 5,
        .allocation_unit_size = 16 * 1024,
    };
    sdmmc_host_t host = SDMMC_HOST_DEFAULT();
    sdmmc_slot_config_t slot_config = SDMMC_SLOT_CONFIG_DEFAULT();

    if (s_mounted) {
        return 0;
    }

    slot_config.width = TF_WIDTH;
    slot_config.clk = TF_CLK;
    slot_config.cmd = TF_CMD;
    slot_config.d0 = TF_D0;

    err = esp_vfs_fat_sdmmc_mount(TF_MOUNT, &host, &slot_config, &mount_config,
                                  &s_card);
    if (err != ESP_OK) {
        s_card = NULL;
        return (int)err;
    }
    s_mounted = 1;
    return 0;
}

int klin_rlcd_tf_unmount(void)
{
    esp_err_t err;

    if (!s_mounted) {
        return 0;
    }
    err = esp_vfs_fat_sdcard_unmount(TF_MOUNT, s_card);
    s_card = NULL;
    s_mounted = 0;
    return (int)err;
}

int klin_rlcd_tf_ready(void)
{
    if (!s_mounted || s_card == NULL) {
        return 0;
    }
    if (sdmmc_get_status(s_card) != ESP_OK) {
        return 0;
    }
    return 1;
}

int klin_rlcd_tf_write(const char *path, const uint8_t *data, int32_t len)
{
    FILE *f;
    size_t n;

    if (!klin_rlcd_tf_ready()) {
        return -1;
    }
    if (path == NULL || data == NULL || len < 0) {
        return -2;
    }
    f = fopen(path, "wb");
    if (f == NULL) {
        return -3;
    }
    n = fwrite(data, 1, (size_t)len, f);
    fclose(f);
    if ((int32_t)n != len) {
        return -4;
    }
    return 0;
}

int klin_rlcd_tf_read(const char *path, uint8_t *buf, int32_t max)
{
    FILE *f;
    size_t n;

    if (!klin_rlcd_tf_ready()) {
        return -1;
    }
    if (path == NULL || buf == NULL || max <= 0) {
        return -2;
    }
    f = fopen(path, "rb");
    if (f == NULL) {
        return -3;
    }
    n = fread(buf, 1, (size_t)max, f);
    fclose(f);
    return (int)n;
}
