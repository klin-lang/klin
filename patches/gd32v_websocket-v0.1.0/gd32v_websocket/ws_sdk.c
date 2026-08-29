#include "ws_sdk.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(__has_include)
#if __has_include("lwip/sockets.h")
#include "lwip/netdb.h"
#include "lwip/sockets.h"
#include <errno.h>
#define KLIN_GD32V_WS_HAVE_LWIP 1
#else
#define KLIN_GD32V_WS_HAVE_LWIP 0
#endif
#else
#define KLIN_GD32V_WS_HAVE_LWIP 0
#endif

#define KLIN_GD32V_WS_IO_MAX 1024
#define KLIN_GD32V_WS_OPCODE_TEXT 1
#define KLIN_GD32V_WS_OPCODE_BIN 2
#define KLIN_GD32V_WS_OPCODE_CLOSE 8
#define KLIN_GD32V_WS_OPCODE_PING 9
#define KLIN_GD32V_WS_OPCODE_PONG 10

static int g_connected = 0;
static int g_last_opcode = 0;
#if KLIN_GD32V_WS_HAVE_LWIP
static int g_fd = -1;
#endif

int klin_gd32v_ws_connected(void) { return g_connected; }

int klin_gd32v_ws_last_opcode(void) { return g_last_opcode; }

#if KLIN_GD32V_WS_HAVE_LWIP

static int parse_ws_uri(const char *uri, char *host, size_t host_cap, int *port,
                        const char **path_out) {
  const char *p = uri;
  *port = 80;
  if (strncmp(p, "ws://", 5) != 0) {
    return -1; /* wss:// later tag */
  }
  p += 5;
  {
    const char *slash = strchr(p, '/');
    const char *colon = strchr(p, ':');
    size_t host_len;
    if (colon != NULL && (slash == NULL || colon < slash)) {
      host_len = (size_t)(colon - p);
      *port = atoi(colon + 1);
    } else if (slash != NULL) {
      host_len = (size_t)(slash - p);
    } else {
      host_len = strlen(p);
    }
    if (host_len == 0 || host_len + 1 > host_cap) {
      return -1;
    }
    memcpy(host, p, host_len);
    host[host_len] = '\0';
    *path_out = (slash != NULL) ? slash : "/";
  }
  return 0;
}

/* --- compact SHA-1 (handshake Accept) --- */
typedef struct {
  uint32_t state[5];
  uint32_t count[2];
  unsigned char buffer[64];
} klin_sha1_ctx;

static uint32_t klin_rol(uint32_t v, int n) {
  return (v << n) | (v >> (32 - n));
}

static void klin_sha1_transform(uint32_t state[5], const unsigned char block[64]) {
  uint32_t a, b, c, d, e, t, w[80];
  int i;
  for (i = 0; i < 16; i++) {
    w[i] = ((uint32_t)block[i * 4] << 24) | ((uint32_t)block[i * 4 + 1] << 16) |
           ((uint32_t)block[i * 4 + 2] << 8) | (uint32_t)block[i * 4 + 3];
  }
  for (i = 16; i < 80; i++) {
    w[i] = klin_rol(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1);
  }
  a = state[0];
  b = state[1];
  c = state[2];
  d = state[3];
  e = state[4];
  for (i = 0; i < 80; i++) {
    if (i < 20) {
      t = klin_rol(a, 5) + ((b & c) | ((~b) & d)) + e + w[i] + 0x5A827999u;
    } else if (i < 40) {
      t = klin_rol(a, 5) + (b ^ c ^ d) + e + w[i] + 0x6ED9EBA1u;
    } else if (i < 60) {
      t = klin_rol(a, 5) + ((b & c) | (b & d) | (c & d)) + e + w[i] +
          0x8F1BBCDCu;
    } else {
      t = klin_rol(a, 5) + (b ^ c ^ d) + e + w[i] + 0xCA62C1D6u;
    }
    e = d;
    d = c;
    c = klin_rol(b, 30);
    b = a;
    a = t;
  }
  state[0] += a;
  state[1] += b;
  state[2] += c;
  state[3] += d;
  state[4] += e;
}

static void klin_sha1_init(klin_sha1_ctx *ctx) {
  ctx->state[0] = 0x67452301u;
  ctx->state[1] = 0xEFCDAB89u;
  ctx->state[2] = 0x98BADCFEu;
  ctx->state[3] = 0x10325476u;
  ctx->state[4] = 0xC3D2E1F0u;
  ctx->count[0] = ctx->count[1] = 0;
}

static void klin_sha1_update(klin_sha1_ctx *ctx, const unsigned char *data,
                             size_t len) {
  size_t i;
  uint32_t idx = (ctx->count[0] >> 3) & 63;
  ctx->count[0] += (uint32_t)(len << 3);
  if (ctx->count[0] < (len << 3)) {
    ctx->count[1]++;
  }
  ctx->count[1] += (uint32_t)(len >> 29);
  for (i = 0; i < len; i++) {
    ctx->buffer[idx++] = data[i];
    if (idx == 64) {
      klin_sha1_transform(ctx->state, ctx->buffer);
      idx = 0;
    }
  }
}

static void klin_sha1_final(unsigned char digest[20], klin_sha1_ctx *ctx) {
  unsigned char finalcount[8];
  unsigned char c;
  int i;
  for (i = 0; i < 8; i++) {
    finalcount[i] =
        (unsigned char)((ctx->count[(i >= 4) ? 0 : 1] >> ((3 - (i & 3)) * 8)) &
                        255);
  }
  c = 0x80;
  klin_sha1_update(ctx, &c, 1);
  while ((ctx->count[0] & 504) != 448) {
    c = 0;
    klin_sha1_update(ctx, &c, 1);
  }
  klin_sha1_update(ctx, finalcount, 8);
  for (i = 0; i < 20; i++) {
    digest[i] =
        (unsigned char)((ctx->state[i >> 2] >> ((3 - (i & 3)) * 8)) & 255);
  }
}

static const char klin_b64[] =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static int klin_b64_encode(const unsigned char *in, int in_len, char *out,
                           int out_cap) {
  int i = 0, o = 0;
  while (i < in_len) {
    int rem = in_len - i;
    unsigned int v = (unsigned int)in[i] << 16;
    if (rem > 1) {
      v |= (unsigned int)in[i + 1] << 8;
    }
    if (rem > 2) {
      v |= (unsigned int)in[i + 2];
    }
    if (o + 4 >= out_cap) {
      return -1;
    }
    out[o++] = klin_b64[(v >> 18) & 63];
    out[o++] = klin_b64[(v >> 12) & 63];
    out[o++] = (rem > 1) ? klin_b64[(v >> 6) & 63] : '=';
    out[o++] = (rem > 2) ? klin_b64[v & 63] : '=';
    i += 3;
  }
  out[o] = '\0';
  return o;
}

static void klin_ws_make_key(char key_b64[29]) {
  unsigned char raw[16];
  int i;
  /* Deterministic-enough key for handshake (not crypto RNG). */
  uint32_t x = 0xA5A5u ^ (uint32_t)(uintptr_t)&raw;
  for (i = 0; i < 16; i++) {
    x = x * 1664525u + 1013904223u;
    raw[i] = (unsigned char)(x >> 24);
  }
  (void)klin_b64_encode(raw, 16, key_b64, 29);
}

static int klin_ws_accept_ok(const char *key_b64, const char *headers) {
  static const char guid[] = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
  klin_sha1_ctx ctx;
  unsigned char digest[20];
  char expect[32];
  char concat[64];
  const char *p;
  int n;

  n = (int)strlen(key_b64);
  if (n + (int)sizeof(guid) > (int)sizeof(concat)) {
    return 0;
  }
  memcpy(concat, key_b64, (size_t)n);
  memcpy(concat + n, guid, sizeof(guid)); /* includes NUL; sha uses n+36 */
  klin_sha1_init(&ctx);
  klin_sha1_update(&ctx, (const unsigned char *)concat, (size_t)(n + 36));
  klin_sha1_final(digest, &ctx);
  if (klin_b64_encode(digest, 20, expect, (int)sizeof(expect)) < 0) {
    return 0;
  }
  p = strstr(headers, "Sec-WebSocket-Accept:");
  if (p == NULL) {
    p = strstr(headers, "sec-websocket-accept:");
  }
  if (p == NULL) {
    return 0;
  }
  p = strchr(p, ':');
  if (p == NULL) {
    return 0;
  }
  p++;
  while (*p == ' ' || *p == '\t') {
    p++;
  }
  return strncmp(p, expect, strlen(expect)) == 0;
}

static int io_write_all(const void *buf, int len) {
  const unsigned char *p = (const unsigned char *)buf;
  int left = len;
  while (left > 0) {
    int n = (int)write(g_fd, p, (size_t)left);
    if (n <= 0) {
      return -1;
    }
    p += n;
    left -= n;
  }
  return len;
}

static int io_read_some(unsigned char *buf, int max) {
  return (int)read(g_fd, buf, (size_t)max);
}

static int ws_send_frame(int opcode, const unsigned char *data, int len) {
  unsigned char hdr[14];
  unsigned char mask[4];
  unsigned char tmp[256];
  int hlen = 0;
  int i;
  uint32_t x;

  if (!g_connected || g_fd < 0 || len < 0) {
    return -1;
  }
  if (len > KLIN_GD32V_WS_IO_MAX - 14) {
    return -1;
  }
  hdr[0] = (unsigned char)(0x80 | (opcode & 0x0f));
  if (len < 126) {
    hdr[1] = (unsigned char)(0x80 | len);
    hlen = 2;
  } else {
    hdr[1] = (unsigned char)(0x80 | 126);
    hdr[2] = (unsigned char)((len >> 8) & 0xff);
    hdr[3] = (unsigned char)(len & 0xff);
    hlen = 4;
  }
  x = 0xC0FFEEu ^ (uint32_t)len;
  for (i = 0; i < 4; i++) {
    x = x * 1664525u + 1013904223u;
    mask[i] = (unsigned char)(x >> 24);
    hdr[hlen++] = mask[i];
  }
  if (io_write_all(hdr, hlen) < 0) {
    return -1;
  }
  /* Mask and send in chunks. */
  i = 0;
  while (i < len) {
    int chunk = len - i;
    int j;
    if (chunk > (int)sizeof(tmp)) {
      chunk = (int)sizeof(tmp);
    }
    for (j = 0; j < chunk; j++) {
      tmp[j] = (unsigned char)(data[i + j] ^ mask[(i + j) & 3]);
    }
    if (io_write_all(tmp, chunk) < 0) {
      return -1;
    }
    i += chunk;
  }
  return 0;
}

int klin_gd32v_ws_connect(const char *uri) {
  char host[128];
  int port = 80;
  const char *path = "/";
  struct addrinfo hints;
  struct addrinfo *res = NULL;
  char port_str[16];
  char key[29];
  char req[512];
  char resp[1024];
  int n, total, req_len;
  struct timeval tv;

  g_last_opcode = 0;
  if (g_connected) {
    (void)klin_gd32v_ws_disconnect();
  }
  if (uri == NULL || parse_ws_uri(uri, host, sizeof(host), &port, &path) != 0) {
    return -1;
  }
  klin_ws_make_key(key);
  req_len = snprintf(req, sizeof(req),
                     "GET %s HTTP/1.1\r\n"
                     "Host: %s:%d\r\n"
                     "Upgrade: websocket\r\n"
                     "Connection: Upgrade\r\n"
                     "Sec-WebSocket-Key: %s\r\n"
                     "Sec-WebSocket-Version: 13\r\n"
                     "\r\n",
                     path, host, port, key);
  if (req_len <= 0 || req_len >= (int)sizeof(req)) {
    return -1;
  }

  memset(&hints, 0, sizeof(hints));
  hints.ai_family = AF_INET;
  hints.ai_socktype = SOCK_STREAM;
  snprintf(port_str, sizeof(port_str), "%d", port);
  if (getaddrinfo(host, port_str, &hints, &res) != 0 || res == NULL) {
    return -1;
  }
  g_fd = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
  if (g_fd < 0) {
    freeaddrinfo(res);
    return -1;
  }
  tv.tv_sec = 5;
  tv.tv_usec = 0;
  (void)setsockopt(g_fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
  if (connect(g_fd, res->ai_addr, res->ai_addrlen) != 0) {
    freeaddrinfo(res);
    close(g_fd);
    g_fd = -1;
    return -1;
  }
  freeaddrinfo(res);

  if (io_write_all(req, req_len) < 0) {
    close(g_fd);
    g_fd = -1;
    return -1;
  }

  total = 0;
  while (total < (int)sizeof(resp) - 1) {
    n = io_read_some((unsigned char *)resp + total,
                     (int)sizeof(resp) - 1 - total);
    if (n <= 0) {
      break;
    }
    total += n;
    resp[total] = '\0';
    if (strstr(resp, "\r\n\r\n") != NULL) {
      break;
    }
  }
  if (total < 12 || strncmp(resp, "HTTP/1.", 7) != 0 ||
      strstr(resp, " 101 ") == NULL) {
    close(g_fd);
    g_fd = -1;
    return -1;
  }
  if (!klin_ws_accept_ok(key, resp)) {
    close(g_fd);
    g_fd = -1;
    return -1;
  }
  g_connected = 1;
  return 0;
}

int klin_gd32v_ws_disconnect(void) {
  if (g_connected && g_fd >= 0) {
    (void)ws_send_frame(KLIN_GD32V_WS_OPCODE_CLOSE, NULL, 0);
    close(g_fd);
  } else if (g_fd >= 0) {
    close(g_fd);
  }
  g_fd = -1;
  g_connected = 0;
  g_last_opcode = 0;
  return 0;
}

int klin_gd32v_ws_send_text(const unsigned char *data, int len) {
  if (data == NULL && len != 0) {
    return -1;
  }
  return ws_send_frame(KLIN_GD32V_WS_OPCODE_TEXT, data, len);
}

int klin_gd32v_ws_send_bin(const unsigned char *data, int len) {
  if (data == NULL && len != 0) {
    return -1;
  }
  return ws_send_frame(KLIN_GD32V_WS_OPCODE_BIN, data, len);
}

/* After a partial/bad frame, drop the socket so the next recv is not misaligned. */
static void ws_force_close(void) {
  if (g_fd >= 0) {
    close(g_fd);
  }
  g_fd = -1;
  g_connected = 0;
  g_last_opcode = 0;
}

int klin_gd32v_ws_recv(unsigned char *out, int out_max) {
  unsigned char buf[KLIN_GD32V_WS_IO_MAX];
  int n, i, opcode, plen;
  unsigned char b1;

  if (!g_connected || g_fd < 0 || out == NULL || out_max < 1) {
    return -1;
  }

  for (;;) {
    n = io_read_some(buf, 2);
    if (n == 0) {
      return 0; /* timeout / no data — stream still aligned */
    }
    if (n < 0) {
      ws_force_close();
      return -1;
    }
    if (n == 1) {
      int n2 = io_read_some(buf + 1, 1);
      if (n2 <= 0) {
        ws_force_close();
        return -1;
      }
    }
    opcode = buf[0] & 0x0f;
    b1 = buf[1];
    if (b1 & 0x80) {
      /* server must not mask */
      ws_force_close();
      return -1;
    }
    plen = b1 & 0x7f;
    if (plen == 126) {
      n = io_read_some(buf + 2, 2);
      if (n < 2) {
        ws_force_close();
        return -1;
      }
      plen = (buf[2] << 8) | buf[3];
    } else if (plen == 127) {
      ws_force_close();
      return -1; /* oversized for MVP */
    }
    if (plen > KLIN_GD32V_WS_IO_MAX) {
      ws_force_close();
      return -1;
    }
    i = 0;
    while (i < plen) {
      n = io_read_some(buf + i, plen - i);
      if (n <= 0) {
        ws_force_close();
        return -1;
      }
      i += n;
    }

    if (opcode == KLIN_GD32V_WS_OPCODE_PING) {
      (void)ws_send_frame(KLIN_GD32V_WS_OPCODE_PONG, buf, plen);
      continue;
    }
    if (opcode == KLIN_GD32V_WS_OPCODE_PONG) {
      continue;
    }
    if (opcode == KLIN_GD32V_WS_OPCODE_CLOSE) {
      ws_force_close();
      return -1;
    }
    if (opcode != KLIN_GD32V_WS_OPCODE_TEXT &&
        opcode != KLIN_GD32V_WS_OPCODE_BIN) {
      continue;
    }
    {
      int take = plen;
      if (take > out_max) {
        take = out_max;
      }
      if (take > 0) {
        memcpy(out, buf, (size_t)take);
      }
      /* NUL only when there is spare room — never overwrite a payload byte. */
      if (take < out_max) {
        out[take] = '\0';
      }
      g_last_opcode = opcode;
      return take;
    }
  }
}

#else /* host stubs */

static int g_stub_pending = 0;
static unsigned char g_stub_payload[8];
static int g_stub_payload_len = 0;
static int g_stub_opcode = 0;

int klin_gd32v_ws_connect(const char *uri) {
  if (uri == NULL || strncmp(uri, "ws://", 5) != 0) {
    return -1;
  }
  g_connected = 1;
  g_last_opcode = 0;
  g_stub_pending = 0;
  return 0;
}

int klin_gd32v_ws_disconnect(void) {
  g_connected = 0;
  g_last_opcode = 0;
  g_stub_pending = 0;
  return 0;
}

int klin_gd32v_ws_send_text(const unsigned char *data, int len) {
  int i;
  if (!g_connected || len < 0 || (data == NULL && len != 0)) {
    return -1;
  }
  g_stub_payload_len = len;
  if (g_stub_payload_len > (int)sizeof(g_stub_payload)) {
    g_stub_payload_len = (int)sizeof(g_stub_payload);
  }
  for (i = 0; i < g_stub_payload_len; i++) {
    g_stub_payload[i] = data[i];
  }
  g_stub_opcode = KLIN_GD32V_WS_OPCODE_TEXT;
  g_stub_pending = 1;
  return 0;
}

int klin_gd32v_ws_send_bin(const unsigned char *data, int len) {
  int i;
  if (!g_connected || len < 0 || (data == NULL && len != 0)) {
    return -1;
  }
  g_stub_payload_len = len;
  if (g_stub_payload_len > (int)sizeof(g_stub_payload)) {
    g_stub_payload_len = (int)sizeof(g_stub_payload);
  }
  for (i = 0; i < g_stub_payload_len; i++) {
    g_stub_payload[i] = data[i];
  }
  g_stub_opcode = KLIN_GD32V_WS_OPCODE_BIN;
  g_stub_pending = 1;
  return 0;
}

int klin_gd32v_ws_recv(unsigned char *out, int out_max) {
  int take;
  if (!g_connected || out == NULL || out_max < 1) {
    return -1;
  }
  if (!g_stub_pending) {
    return 0;
  }
  take = g_stub_payload_len;
  if (take > out_max) {
    take = out_max;
  }
  if (take > 0) {
    memcpy(out, g_stub_payload, (size_t)take);
  }
  /* NUL only when there is spare room — never overwrite a payload byte. */
  if (take < out_max) {
    out[take] = '\0';
  }
  g_last_opcode = g_stub_opcode;
  g_stub_pending = 0;
  return take;
}

#endif /* HAVE_LWIP */
