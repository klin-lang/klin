/* Thin HTTP(+TLS) client helpers for Klin on GD32VW55x.
 * Does not bring up Wi‑Fi — need IP first (gd32v_wifi).
 * Response body always goes into a caller buffer (no Klin heap / hidden store).
 * TLS: explicit caller PEM via mbedTLS — never an implicit Klin CA store.
 * No IDF-style crt bundle on this platform (use PEM).
 */
#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Cleartext HTTP. Returns body bytes written, or -1. */
int klin_gd32v_http_get(const char *url, char *out_body, int out_cap);
int klin_gd32v_http_post(const char *url, const void *body, int body_len,
                         char *out_body, int out_cap);

/* HTTPS with caller PEM CA/server cert (NUL-terminated). Returns body bytes, or -1. */
int klin_gd32v_http_get_tls_pem(const char *url, const char *ca_pem,
                                char *out_body, int out_cap);
int klin_gd32v_http_post_tls_pem(const char *url, const char *ca_pem,
                                 const void *body, int body_len, char *out_body,
                                 int out_cap);

int klin_gd32v_http_last_status(void);
int klin_gd32v_http_last_content_length(void);

#ifdef __cplusplus
}
#endif
