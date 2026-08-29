/* Thin CoAP (RFC 7252) client for Klin on GD32VW55x.
 * Does not bring up Wi‑Fi — need IP first (gd32v_wifi).
 * UDP over LwIP when `lwip/sockets.h` is present; host stubs otherwise.
 * Response payload always goes into a caller buffer.
 * Confirm (CON) vs non-confirm (NON) is an explicit argument.
 * Not libcoap FFI — minimal encode/decode over UDP (sibling of gd32v_http).
 */
#pragma once

#ifdef __cplusplus
extern "C" {
#endif

/**
 * CoAP GET. `uri` like `coap://host[:port]/path`.
 * `confirm` != 0 → CON, else NON.
 * Returns payload bytes written, or -1.
 */
int klin_gd32v_coap_get(const char *uri, unsigned char *out, int out_max,
                        int confirm);

/**
 * CoAP PUT. Body is a caller buffer. Returns response payload bytes, or -1.
 */
int klin_gd32v_coap_put(const char *uri, const unsigned char *body, int body_len,
                        unsigned char *out, int out_max, int confirm);

/** Last CoAP response code (e.g. 69 = 2.05 Content), or 0. */
int klin_gd32v_coap_last_code(void);

#ifdef __cplusplus
}
#endif
