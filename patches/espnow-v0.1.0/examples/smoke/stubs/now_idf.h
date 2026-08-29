/* Host smoke stubs — same surface as esp_now/now_idf.h (no ESP-IDF). */
#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

int klin_now_data_max(void);
int klin_now_recv_queue_max(void);
int klin_now_init(void);
int klin_now_deinit(void);
int klin_now_set_channel(int channel);
int klin_now_channel(void);
int klin_now_mac_self(uint8_t *out6);
int klin_now_add_peer(const uint8_t *mac6, int channel);
int klin_now_del_peer(const uint8_t *mac6);
int klin_now_peer_exists(const uint8_t *mac6);
int klin_now_add_broadcast(void);
int klin_now_send(const uint8_t *mac6, const uint8_t *data, int len);
int klin_now_send_wait(int timeout_ms);
int klin_now_send_ok(void);
int klin_now_send_done(void);
int klin_now_recv_count(void);
int klin_now_recv(uint8_t *mac6_out, uint8_t *out, int max_len);
void klin_now_log_self(void);

#ifdef __cplusplus
}
#endif
