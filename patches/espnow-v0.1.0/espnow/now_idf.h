/* Thin ESP-NOW helpers for Klin — Wi-Fi STA + esp_now_* under ESP-IDF v5.x.
 * Heap, NVS, Wi-Fi task, and the default event loop are ESP-IDF contracts.
 * No Klin GC: peer MAC / payloads are caller buffers; RX is a fixed C ring.
 */
#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/** Max payload bytes per frame (ESP-NOW v1 / ESP_NOW_MAX_DATA_LEN). */
int klin_now_data_max(void);

/** Fixed RX ring depth (documented). Overflow drops the newest frame. */
int klin_now_recv_queue_max(void);

/**
 * NVS + netif + default event loop + esp_wifi STA (no AP assoc) +
 * esp_wifi_start + default channel 1 + esp_now_init + send/recv callbacks.
 * Returns esp_err_t as int (0 = OK).
 */
int klin_now_init(void);

/** esp_now_deinit + esp_wifi_stop. Clears peers and the RX ring. */
int klin_now_deinit(void);

/**
 * Set primary Wi-Fi channel (1..13) for ESP-NOW. Both peers must match.
 * Call after init. Returns esp_err_t as int.
 */
int klin_now_set_channel(int channel);

/** Last channel set via set_channel / init default (1). */
int klin_now_channel(void);

/**
 * Copy this station MAC (6 bytes) into out6.
 * Returns 0 on OK, else esp_err_t / -1.
 */
int klin_now_mac_self(uint8_t *out6);

/**
 * Add an unencrypted peer. mac6 = 6 bytes. channel 0 = use current channel.
 * Broadcast MAC (ff:ff:ff:ff:ff:ff) is allowed (needed before send_broadcast).
 */
int klin_now_add_peer(const uint8_t *mac6, int channel);

int klin_now_del_peer(const uint8_t *mac6);

/** 1 if peer is in the ESP-NOW peer list. */
int klin_now_peer_exists(const uint8_t *mac6);

/** Convenience: add broadcast peer on the current channel. */
int klin_now_add_broadcast(void);

/**
 * Send len bytes from data to mac6. len must be 1..data_max.
 * Returns esp_err_t as int. Does not wait for the send callback.
 */
int klin_now_send(const uint8_t *mac6, const uint8_t *data, int len);

/**
 * Block until the last send callback runs or timeout_ms (-1 = forever).
 * Returns 0 if send_ok, else esp_err_t / fail.
 */
int klin_now_send_wait(int timeout_ms);

/** 1 after a successful MAC-layer send callback for the last send. */
int klin_now_send_ok(void);

/** 1 after the send callback ran (success or fail) since last send. */
int klin_now_send_done(void);

/** Number of frames waiting in the RX ring (0..recv_queue_max). */
int klin_now_recv_count(void);

/**
 * Pop oldest RX frame: copy MAC into mac6_out (6 bytes) and payload into out.
 * Returns payload length, or esp_err_t / -1 if empty / bad args.
 */
int klin_now_recv(uint8_t *mac6_out, uint8_t *out, int max_len);

/** Debug printf of own MAC + channel. */
void klin_now_log_self(void);

#ifdef __cplusplus
}
#endif
