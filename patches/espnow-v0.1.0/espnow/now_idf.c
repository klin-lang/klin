/* ESP-NOW bring-up for Klin apps under ESP-IDF v5.x.
 * Explicit steps; caller sees every return code via Klin wrappers.
 * Unencrypted peers only on this tag (PMK/LMK later).
 */
#include "now_idf.h"

#include <stdio.h>
#include <string.h>

#include "esp_event.h"
#include "esp_idf_version.h"
#include "esp_mac.h"
#include "esp_netif.h"
#include "esp_now.h"
#include "esp_wifi.h"
#include "freertos/FreeRTOS.h"
#include "freertos/event_groups.h"
#include "nvs_flash.h"

#define KLIN_NOW_SEND_DONE_BIT BIT0
#define KLIN_NOW_DATA_MAX      ESP_NOW_MAX_DATA_LEN
#define KLIN_NOW_RX_MAX        8
#define KLIN_NOW_MAC_LEN       6

typedef struct {
    uint8_t mac[KLIN_NOW_MAC_LEN];
    uint8_t data[KLIN_NOW_DATA_MAX];
    uint16_t len;
    uint8_t used;
} klin_now_rx_slot_t;

static EventGroupHandle_t s_now_event_group;
static int s_inited;
static int s_channel = 1;
static int s_send_ok;
static int s_send_done;
static klin_now_rx_slot_t s_rx[KLIN_NOW_RX_MAX];
static int s_rx_head; /* next pop */
static int s_rx_tail; /* next push */
static int s_rx_count;

static const uint8_t s_broadcast[KLIN_NOW_MAC_LEN] = {
    0xff, 0xff, 0xff, 0xff, 0xff, 0xff};

int klin_now_data_max(void)
{
    return KLIN_NOW_DATA_MAX;
}

int klin_now_recv_queue_max(void)
{
    return KLIN_NOW_RX_MAX;
}

static void klin_now_rx_clear(void)
{
    memset(s_rx, 0, sizeof(s_rx));
    s_rx_head = 0;
    s_rx_tail = 0;
    s_rx_count = 0;
}

static void klin_now_mark_send_done(esp_now_send_status_t status)
{
    s_send_done = 1;
    s_send_ok = (status == ESP_NOW_SEND_SUCCESS) ? 1 : 0;
    if (s_now_event_group != NULL) {
        xEventGroupSetBits(s_now_event_group, KLIN_NOW_SEND_DONE_BIT);
    }
}

/* IDF ≥5.5: first arg is esp_now_send_info_t*; earlier: peer MAC. */
#if ESP_IDF_VERSION >= ESP_IDF_VERSION_VAL(5, 5, 0)
static void klin_now_send_cb(const esp_now_send_info_t *tx_info,
                             esp_now_send_status_t status)
{
    (void)tx_info;
    klin_now_mark_send_done(status);
}
#else
static void klin_now_send_cb(const uint8_t *mac_addr, esp_now_send_status_t status)
{
    (void)mac_addr;
    klin_now_mark_send_done(status);
}
#endif

static void klin_now_push_rx(const uint8_t *src_mac, const uint8_t *data, int len)
{
    klin_now_rx_slot_t *slot;

    if (src_mac == NULL || data == NULL || len <= 0) {
        return;
    }
    if (s_rx_count >= KLIN_NOW_RX_MAX) {
        /* Overflow: drop newest (documented; matches scan-style policy). */
        return;
    }
    if (len > KLIN_NOW_DATA_MAX) {
        len = KLIN_NOW_DATA_MAX;
    }

    slot = &s_rx[s_rx_tail];
    memcpy(slot->mac, src_mac, KLIN_NOW_MAC_LEN);
    memcpy(slot->data, data, (size_t)len);
    slot->len = (uint16_t)len;
    slot->used = 1;
    s_rx_tail = (s_rx_tail + 1) % KLIN_NOW_RX_MAX;
    s_rx_count++;
}

/* IDF v5.x: esp_now_recv_info_t + data/len. */
static void klin_now_recv_cb(const esp_now_recv_info_t *info, const uint8_t *data,
                             int len)
{
    if (info == NULL) {
        return;
    }
    klin_now_push_rx(info->src_addr, data, len);
}

int klin_now_init(void)
{
    esp_err_t err;
    wifi_init_config_t cfg;

    if (s_inited) {
        return (int)ESP_OK;
    }

    err = nvs_flash_init();
    if (err == ESP_ERR_NVS_NO_FREE_PAGES || err == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        err = nvs_flash_erase();
        if (err != ESP_OK) {
            return (int)err;
        }
        err = nvs_flash_init();
    }
    if (err != ESP_OK) {
        return (int)err;
    }

    err = esp_netif_init();
    if (err != ESP_OK) {
        return (int)err;
    }

    err = esp_event_loop_create_default();
    if (err != ESP_OK && err != ESP_ERR_INVALID_STATE) {
        return (int)err;
    }

    if (esp_netif_create_default_wifi_sta() == NULL) {
        return (int)ESP_FAIL;
    }

    cfg = (wifi_init_config_t)WIFI_INIT_CONFIG_DEFAULT();
    err = esp_wifi_init(&cfg);
    if (err != ESP_OK) {
        return (int)err;
    }

    err = esp_wifi_set_storage(WIFI_STORAGE_RAM);
    if (err != ESP_OK) {
        return (int)err;
    }

    err = esp_wifi_set_mode(WIFI_MODE_STA);
    if (err != ESP_OK) {
        return (int)err;
    }

    err = esp_wifi_start();
    if (err != ESP_OK) {
        return (int)err;
    }

    s_channel = 1;
    err = esp_wifi_set_channel((uint8_t)s_channel, WIFI_SECOND_CHAN_NONE);
    if (err != ESP_OK) {
        return (int)err;
    }

    s_now_event_group = xEventGroupCreate();
    if (s_now_event_group == NULL) {
        return (int)ESP_ERR_NO_MEM;
    }

    klin_now_rx_clear();
    s_send_ok = 0;
    s_send_done = 0;

    err = esp_now_init();
    if (err != ESP_OK) {
        return (int)err;
    }

    err = esp_now_register_send_cb(klin_now_send_cb);
    if (err != ESP_OK) {
        return (int)err;
    }

    err = esp_now_register_recv_cb(klin_now_recv_cb);
    if (err != ESP_OK) {
        return (int)err;
    }

    s_inited = 1;
    return (int)ESP_OK;
}

int klin_now_deinit(void)
{
    esp_err_t err;

    if (!s_inited) {
        return (int)ESP_OK;
    }

    (void)esp_now_unregister_recv_cb();
    (void)esp_now_unregister_send_cb();
    err = esp_now_deinit();
    (void)esp_wifi_stop();

    if (s_now_event_group != NULL) {
        vEventGroupDelete(s_now_event_group);
        s_now_event_group = NULL;
    }

    klin_now_rx_clear();
    s_send_ok = 0;
    s_send_done = 0;
    s_inited = 0;
    return (int)err;
}

int klin_now_set_channel(int channel)
{
    esp_err_t err;

    if (!s_inited) {
        return (int)ESP_ERR_INVALID_STATE;
    }
    if (channel < 1 || channel > 13) {
        return (int)ESP_ERR_INVALID_ARG;
    }

    err = esp_wifi_set_channel((uint8_t)channel, WIFI_SECOND_CHAN_NONE);
    if (err != ESP_OK) {
        return (int)err;
    }
    s_channel = channel;
    return (int)ESP_OK;
}

int klin_now_channel(void)
{
    return s_channel;
}

int klin_now_mac_self(uint8_t *out6)
{
    if (out6 == NULL) {
        return -1;
    }
    return (int)esp_wifi_get_mac(WIFI_IF_STA, out6);
}

int klin_now_add_peer(const uint8_t *mac6, int channel)
{
    esp_now_peer_info_t peer;
    int ch;

    if (!s_inited) {
        return (int)ESP_ERR_INVALID_STATE;
    }
    if (mac6 == NULL) {
        return (int)ESP_ERR_INVALID_ARG;
    }

    ch = channel;
    if (ch == 0) {
        ch = s_channel;
    }
    if (ch < 1 || ch > 13) {
        return (int)ESP_ERR_INVALID_ARG;
    }

    memset(&peer, 0, sizeof(peer));
    memcpy(peer.peer_addr, mac6, KLIN_NOW_MAC_LEN);
    peer.channel = (uint8_t)ch;
    peer.ifidx = WIFI_IF_STA;
    peer.encrypt = false;

    if (esp_now_is_peer_exist(mac6)) {
        return (int)esp_now_mod_peer(&peer);
    }
    return (int)esp_now_add_peer(&peer);
}

int klin_now_del_peer(const uint8_t *mac6)
{
    if (!s_inited) {
        return (int)ESP_ERR_INVALID_STATE;
    }
    if (mac6 == NULL) {
        return (int)ESP_ERR_INVALID_ARG;
    }
    return (int)esp_now_del_peer(mac6);
}

int klin_now_peer_exists(const uint8_t *mac6)
{
    if (!s_inited || mac6 == NULL) {
        return 0;
    }
    return esp_now_is_peer_exist(mac6) ? 1 : 0;
}

int klin_now_add_broadcast(void)
{
    return klin_now_add_peer(s_broadcast, 0);
}

int klin_now_send(const uint8_t *mac6, const uint8_t *data, int len)
{
    if (!s_inited) {
        return (int)ESP_ERR_INVALID_STATE;
    }
    if (mac6 == NULL || data == NULL || len < 1 || len > KLIN_NOW_DATA_MAX) {
        return (int)ESP_ERR_INVALID_ARG;
    }

    s_send_ok = 0;
    s_send_done = 0;
    if (s_now_event_group != NULL) {
        xEventGroupClearBits(s_now_event_group, KLIN_NOW_SEND_DONE_BIT);
    }
    return (int)esp_now_send(mac6, data, (size_t)len);
}

int klin_now_send_wait(int timeout_ms)
{
    EventBits_t bits;
    TickType_t ticks;

    if (!s_inited) {
        return (int)ESP_ERR_INVALID_STATE;
    }
    if (s_now_event_group == NULL) {
        return (int)ESP_ERR_INVALID_STATE;
    }

    if (timeout_ms < 0) {
        ticks = portMAX_DELAY;
    } else {
        ticks = pdMS_TO_TICKS((uint32_t)timeout_ms);
    }

    bits = xEventGroupWaitBits(s_now_event_group, KLIN_NOW_SEND_DONE_BIT, pdTRUE,
                               pdFALSE, ticks);
    if ((bits & KLIN_NOW_SEND_DONE_BIT) == 0) {
        return (int)ESP_ERR_TIMEOUT;
    }
    return s_send_ok ? (int)ESP_OK : (int)ESP_FAIL;
}

int klin_now_send_ok(void)
{
    return s_send_ok;
}

int klin_now_send_done(void)
{
    return s_send_done;
}

int klin_now_recv_count(void)
{
    return s_rx_count;
}

int klin_now_recv(uint8_t *mac6_out, uint8_t *out, int max_len)
{
    klin_now_rx_slot_t *slot;
    int n;

    if (mac6_out == NULL || out == NULL || max_len < 1) {
        return -1;
    }
    if (s_rx_count < 1) {
        return (int)ESP_FAIL;
    }

    slot = &s_rx[s_rx_head];
    n = (int)slot->len;
    if (n > max_len) {
        n = max_len;
    }
    memcpy(mac6_out, slot->mac, KLIN_NOW_MAC_LEN);
    memcpy(out, slot->data, (size_t)n);
    slot->used = 0;
    slot->len = 0;
    s_rx_head = (s_rx_head + 1) % KLIN_NOW_RX_MAX;
    s_rx_count--;
    return n;
}

void klin_now_log_self(void)
{
    uint8_t mac[KLIN_NOW_MAC_LEN];

    if (klin_now_mac_self(mac) != 0) {
        printf("esp_now: mac unknown, ch=%d\n", s_channel);
        return;
    }
    printf("esp_now: mac=%02x:%02x:%02x:%02x:%02x:%02x ch=%d\n", mac[0], mac[1],
           mac[2], mac[3], mac[4], mac[5], s_channel);
}
