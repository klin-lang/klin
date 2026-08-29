#include "coap_sdk.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(__has_include)
#if __has_include("lwip/sockets.h")
#include "lwip/netdb.h"
#include "lwip/sockets.h"
#include <errno.h>
#define KLIN_GD32V_COAP_HAVE_LWIP 1
#else
#define KLIN_GD32V_COAP_HAVE_LWIP 0
#endif
#else
#define KLIN_GD32V_COAP_HAVE_LWIP 0
#endif

#define KLIN_GD32V_COAP_PKT_MAX 512
#define KLIN_GD32V_COAP_DEFAULT_PORT 5683
#define KLIN_GD32V_COAP_CODE_GET 1
#define KLIN_GD32V_COAP_CODE_PUT 3
#define KLIN_GD32V_COAP_OPT_URI_PATH 11
#define KLIN_GD32V_COAP_TYPE_CON 0
#define KLIN_GD32V_COAP_TYPE_NON 1
#define KLIN_GD32V_COAP_TYPE_ACK 2

static int g_last_code = 0;

int klin_gd32v_coap_last_code(void) { return g_last_code; }

#if KLIN_GD32V_COAP_HAVE_LWIP

static uint16_t g_msg_id = 1;

static int parse_coap_uri(const char *uri, char *host, size_t host_cap, int *port,
                          const char **path_out) {
  const char *p = uri;
  *port = KLIN_GD32V_COAP_DEFAULT_PORT;
  if (strncmp(p, "coap://", 7) != 0) {
    return -1;
  }
  p += 7;
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

static int append_option(unsigned char *pkt, int *len, int *last_num, int opt_num,
                         const unsigned char *val, int val_len, int max) {
  int delta = opt_num - *last_num;
  int start = *len;
  unsigned char nibble_d;
  unsigned char nibble_l;
  int need = 1;

  if (delta < 0 || val_len < 0) {
    return -1;
  }
  if (delta < 13) {
    nibble_d = (unsigned char)delta;
  } else if (delta < 269) {
    nibble_d = 13;
    need += 1;
  } else {
    nibble_d = 14;
    need += 2;
  }
  if (val_len < 13) {
    nibble_l = (unsigned char)val_len;
  } else if (val_len < 269) {
    nibble_l = 13;
    need += 1;
  } else {
    nibble_l = 14;
    need += 2;
  }
  need += val_len;
  if (start + need > max) {
    return -1;
  }
  pkt[start++] = (unsigned char)((nibble_d << 4) | nibble_l);
  if (nibble_d == 13) {
    pkt[start++] = (unsigned char)(delta - 13);
  } else if (nibble_d == 14) {
    int d = delta - 269;
    pkt[start++] = (unsigned char)((d >> 8) & 0xff);
    pkt[start++] = (unsigned char)(d & 0xff);
  }
  if (nibble_l == 13) {
    pkt[start++] = (unsigned char)(val_len - 13);
  } else if (nibble_l == 14) {
    int l = val_len - 269;
    pkt[start++] = (unsigned char)((l >> 8) & 0xff);
    pkt[start++] = (unsigned char)(l & 0xff);
  }
  if (val_len > 0) {
    memcpy(pkt + start, val, (size_t)val_len);
    start += val_len;
  }
  *len = start;
  *last_num = opt_num;
  return 0;
}

static int build_request(unsigned char *pkt, int max, int confirm, int code,
                         uint16_t mid, const char *path, const unsigned char *body,
                         int body_len) {
  int len = 0;
  int last_opt = 0;
  unsigned char type = confirm ? KLIN_GD32V_COAP_TYPE_CON : KLIN_GD32V_COAP_TYPE_NON;
  const char *seg;
  const char *p;

  if (max < 4) {
    return -1;
  }
  pkt[0] = (unsigned char)((1 << 6) | (type << 4) | 0); /* Ver=1, TKL=0 */
  pkt[1] = (unsigned char)code;
  pkt[2] = (unsigned char)((mid >> 8) & 0xff);
  pkt[3] = (unsigned char)(mid & 0xff);
  len = 4;

  p = path;
  if (p == NULL || p[0] == '\0') {
    p = "/";
  }
  if (p[0] == '/') {
    p++;
  }
  while (*p) {
    seg = p;
    while (*p && *p != '/') {
      p++;
    }
    if (p > seg) {
      if (append_option(pkt, &len, &last_opt, KLIN_GD32V_COAP_OPT_URI_PATH,
                        (const unsigned char *)seg, (int)(p - seg), max) != 0) {
        return -1;
      }
    }
    if (*p == '/') {
      p++;
    }
  }

  if (body != NULL && body_len > 0) {
    if (len + 1 + body_len > max) {
      return -1;
    }
    pkt[len++] = 0xff;
    memcpy(pkt + len, body, (size_t)body_len);
    len += body_len;
  }
  return len;
}

static int parse_response(const unsigned char *pkt, int pkt_len, uint16_t expect_mid,
                          unsigned char *out, int out_max) {
  int i;
  int tkl;
  int type;
  int code;
  uint16_t mid;
  int opt_num = 0;

  if (pkt_len < 4) {
    return -1;
  }
  if (((pkt[0] >> 6) & 0x3) != 1) {
    return -1;
  }
  type = (pkt[0] >> 4) & 0x3;
  tkl = pkt[0] & 0x0f;
  code = pkt[1];
  mid = (uint16_t)((pkt[2] << 8) | pkt[3]);
  if (mid != expect_mid) {
    return -1;
  }
  i = 4 + tkl;
  if (i > pkt_len) {
    return -1;
  }

  /* Skip options until payload marker or end. */
  while (i < pkt_len && pkt[i] != 0xff) {
    int delta = (pkt[i] >> 4) & 0x0f;
    int olen = pkt[i] & 0x0f;
    i++;
    if (delta == 13) {
      if (i >= pkt_len) {
        return -1;
      }
      delta = pkt[i++] + 13;
    } else if (delta == 14) {
      if (i + 1 >= pkt_len) {
        return -1;
      }
      delta = ((pkt[i] << 8) | pkt[i + 1]) + 269;
      i += 2;
    } else if (delta == 15) {
      return -1;
    }
    if (olen == 13) {
      if (i >= pkt_len) {
        return -1;
      }
      olen = pkt[i++] + 13;
    } else if (olen == 14) {
      if (i + 1 >= pkt_len) {
        return -1;
      }
      olen = ((pkt[i] << 8) | pkt[i + 1]) + 269;
      i += 2;
    } else if (olen == 15) {
      return -1;
    }
    opt_num += delta;
    (void)opt_num;
    if (i + olen > pkt_len) {
      return -1;
    }
    i += olen;
  }

  g_last_code = code;

  /* Empty ACK (CON without piggyback) — caller may retry wait. */
  if (type == KLIN_GD32V_COAP_TYPE_ACK && code == 0) {
    return -2;
  }

  if (i < pkt_len && pkt[i] == 0xff) {
    int plen;
    i++;
    plen = pkt_len - i;
    if (out != NULL && out_max > 0) {
      int take = plen;
      if (take > out_max) {
        take = out_max;
      }
      if (take > 0) {
        memcpy(out, pkt + i, (size_t)take);
      }
      if (take < out_max) {
        out[take] = '\0';
      } else if (out_max > 0) {
        out[out_max - 1] = '\0';
      }
      return take;
    }
    return plen;
  }
  if (out != NULL && out_max > 0) {
    out[0] = '\0';
  }
  return 0;
}

static int coap_exchange(const char *uri, int code, const unsigned char *body,
                         int body_len, unsigned char *out, int out_max,
                         int confirm) {
  char host[128];
  int port = KLIN_GD32V_COAP_DEFAULT_PORT;
  const char *path = "/";
  struct addrinfo hints;
  struct addrinfo *res = NULL;
  char port_str[16];
  int fd = -1;
  unsigned char req[KLIN_GD32V_COAP_PKT_MAX];
  unsigned char rsp[KLIN_GD32V_COAP_PKT_MAX];
  int req_len;
  int n;
  uint16_t mid;
  struct timeval tv;
  int attempts;
  int got;

  g_last_code = 0;
  if (uri == NULL || (out_max > 0 && out == NULL)) {
    return -1;
  }
  if (parse_coap_uri(uri, host, sizeof(host), &port, &path) != 0) {
    return -1;
  }
  mid = g_msg_id++;
  if (g_msg_id == 0) {
    g_msg_id = 1;
  }
  req_len = build_request(req, (int)sizeof(req), confirm, code, mid, path, body,
                          body_len);
  if (req_len < 0) {
    return -1;
  }

  memset(&hints, 0, sizeof(hints));
  hints.ai_family = AF_INET;
  hints.ai_socktype = SOCK_DGRAM;
  snprintf(port_str, sizeof(port_str), "%d", port);
  if (getaddrinfo(host, port_str, &hints, &res) != 0 || res == NULL) {
    return -1;
  }
  fd = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
  if (fd < 0) {
    freeaddrinfo(res);
    return -1;
  }
  tv.tv_sec = 3;
  tv.tv_usec = 0;
  (void)setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));

  attempts = confirm ? 3 : 1;
  got = -1;
  while (attempts-- > 0) {
    if (sendto(fd, req, (size_t)req_len, 0, res->ai_addr, res->ai_addrlen) !=
        req_len) {
      break;
    }
    for (;;) {
      n = (int)recvfrom(fd, rsp, sizeof(rsp), 0, NULL, NULL);
      if (n <= 0) {
        break;
      }
      got = parse_response(rsp, n, mid, out, out_max);
      if (got == -2) {
        /* empty ACK — keep waiting for separate response */
        continue;
      }
      if (got >= 0) {
        freeaddrinfo(res);
        close(fd);
        return got;
      }
      /* wrong mid / bad PDU — keep waiting once */
    }
  }

  freeaddrinfo(res);
  close(fd);
  return -1;
}

int klin_gd32v_coap_get(const char *uri, unsigned char *out, int out_max,
                        int confirm) {
  return coap_exchange(uri, KLIN_GD32V_COAP_CODE_GET, NULL, 0, out, out_max,
                       confirm);
}

int klin_gd32v_coap_put(const char *uri, const unsigned char *body, int body_len,
                        unsigned char *out, int out_max, int confirm) {
  if (body_len < 0 || (body_len > 0 && body == NULL)) {
    return -1;
  }
  return coap_exchange(uri, KLIN_GD32V_COAP_CODE_PUT, body, body_len, out,
                       out_max, confirm);
}

#else /* host stubs */

int klin_gd32v_coap_get(const char *uri, unsigned char *out, int out_max,
                        int confirm) {
  (void)uri;
  (void)confirm;
  g_last_code = 69; /* 2.05 Content */
  if (out == NULL || out_max < 3) {
    return -1;
  }
  out[0] = 'o';
  out[1] = 'k';
  out[2] = '\0';
  return 2;
}

int klin_gd32v_coap_put(const char *uri, const unsigned char *body, int body_len,
                        unsigned char *out, int out_max, int confirm) {
  (void)uri;
  (void)body;
  (void)body_len;
  (void)confirm;
  g_last_code = 68; /* 2.04 Changed */
  if (out != NULL && out_max > 0) {
    out[0] = '\0';
  }
  return 0;
}

#endif /* HAVE_LWIP */
