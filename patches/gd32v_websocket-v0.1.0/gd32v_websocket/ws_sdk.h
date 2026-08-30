/* Thin WebSocket (RFC 6455) client for Klin on GD32VW55x.
 * Does not bring up Wi‑Fi — need IP first (gd32v_wifi).
 * Cleartext `ws://` over LwIP TCP when `lwip/sockets.h` is present;
 * host stubs otherwise. TLS (`wss://` + PEM) is a later tag.
 * Frames use caller buffers; fixed C I/O buffers (no Klin heap).
 * Not a tinyws FFI wrapper. Not a WebSocket server.
 */
#pragma once

#ifdef __cplusplus
extern "C" {
#endif

/** Connect to `ws://host[:port]/path` (default port 80). Returns 0 or -1. */
int klin_gd32v_ws_connect(const char *uri);

int klin_gd32v_ws_disconnect(void);

/** 1 if connected. */
int klin_gd32v_ws_connected(void);

/** Send a text frame (opcode 1). Payload is a caller buffer. */
int klin_gd32v_ws_send_text(const unsigned char *data, int len);

/** Send a binary frame (opcode 2). */
int klin_gd32v_ws_send_bin(const unsigned char *data, int len);

/**
 * Receive one data frame into caller buffer.
 * Returns payload bytes, `0` if none/timeout, `-1` on error / closed.
 * PING frames are answered with PONG and do not return to the caller.
 */
int klin_gd32v_ws_recv(unsigned char *out, int out_max);

/** Last data opcode after a successful `recv` (`1` text, `2` binary), else 0. */
int klin_gd32v_ws_last_opcode(void);

#ifdef __cplusplus
}
#endif
