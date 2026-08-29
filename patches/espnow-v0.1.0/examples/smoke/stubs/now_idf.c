#include "now_idf.h"

#include <string.h>

static uint8_t s_mac[6] = {0x11, 0x22, 0x33, 0x44, 0x55, 0x66};
static int s_channel = 1;
static int s_inited;
static int s_send_ok;
static int s_send_done;
static int s_recv_count;
static uint8_t s_peer[6];
static int s_has_peer;
static uint8_t s_rx_mac[6];
static uint8_t s_rx_data[250];
static int s_rx_len;

int klin_now_data_max(void)
{
    return 250;
}

int klin_now_recv_queue_max(void)
{
    return 8;
}

int klin_now_init(void)
{
    s_inited = 1;
    s_channel = 1;
    s_send_ok = 0;
    s_send_done = 0;
    s_recv_count = 0;
    s_has_peer = 0;
    s_rx_len = 0;
    return 0;
}

int klin_now_deinit(void)
{
    s_inited = 0;
    s_has_peer = 0;
    s_recv_count = 0;
    return 0;
}

int klin_now_set_channel(int channel)
{
    if (!s_inited) {
        return -1;
    }
    if (channel < 1 || channel > 13) {
        return -1;
    }
    s_channel = channel;
    return 0;
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
    memcpy(out6, s_mac, 6);
    return 0;
}

int klin_now_add_peer(const uint8_t *mac6, int channel)
{
    (void)channel;
    if (!s_inited || mac6 == NULL) {
        return -1;
    }
    memcpy(s_peer, mac6, 6);
    s_has_peer = 1;
    return 0;
}

int klin_now_del_peer(const uint8_t *mac6)
{
    (void)mac6;
    s_has_peer = 0;
    return 0;
}

int klin_now_peer_exists(const uint8_t *mac6)
{
    int i;

    if (!s_inited || !s_has_peer || mac6 == NULL) {
        return 0;
    }
    for (i = 0; i < 6; i++) {
        if (s_peer[i] != mac6[i]) {
            return 0;
        }
    }
    return 1;
}

int klin_now_add_broadcast(void)
{
    static const uint8_t bc[6] = {0xff, 0xff, 0xff, 0xff, 0xff, 0xff};
    return klin_now_add_peer(bc, 0);
}

int klin_now_send(const uint8_t *mac6, const uint8_t *data, int len)
{
    if (!s_inited || mac6 == NULL || data == NULL || len < 1 || len > 250) {
        return -1;
    }
    s_send_done = 1;
    s_send_ok = 1;
    /* Echo into RX so smoke can exercise recv without radio. */
    memcpy(s_rx_mac, mac6, 6);
    memcpy(s_rx_data, data, (size_t)len);
    s_rx_len = len;
    s_recv_count = 1;
    return 0;
}

int klin_now_send_wait(int timeout_ms)
{
    (void)timeout_ms;
    return s_send_ok ? 0 : -1;
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
    return s_recv_count;
}

int klin_now_recv(uint8_t *mac6_out, uint8_t *out, int max_len)
{
    int n;

    if (mac6_out == NULL || out == NULL || max_len < 1) {
        return -1;
    }
    if (s_recv_count < 1) {
        return -1;
    }
    n = s_rx_len;
    if (n > max_len) {
        n = max_len;
    }
    memcpy(mac6_out, s_rx_mac, 6);
    memcpy(out, s_rx_data, (size_t)n);
    s_recv_count = 0;
    return n;
}

void klin_now_log_self(void) {}
