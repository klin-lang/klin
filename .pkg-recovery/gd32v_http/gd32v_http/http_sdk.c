#include "http_sdk.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(__has_include)
#if __has_include("lwip/sockets.h")
#include "lwip/sockets.h"
#include "lwip/netdb.h"
#include <errno.h>
#define KLIN_GD32V_HTTP_HAVE_LWIP 1
#else
#define KLIN_GD32V_HTTP_HAVE_LWIP 0
#endif
#if __has_include("mbedtls/ssl.h")
#include "mbedtls/ctr_drbg.h"
#include "mbedtls/entropy.h"
#include "mbedtls/error.h"
#include "mbedtls/net_sockets.h"
#include "mbedtls/ssl.h"
#include "mbedtls/x509_crt.h"
#define KLIN_GD32V_HTTP_HAVE_MBEDTLS 1
#else
#define KLIN_GD32V_HTTP_HAVE_MBEDTLS 0
#endif
#else
#define KLIN_GD32V_HTTP_HAVE_LWIP 0
#define KLIN_GD32V_HTTP_HAVE_MBEDTLS 0
#endif

static int g_last_status = 0;
static int g_last_content_length = -1;

int klin_gd32v_http_last_status(void) { return g_last_status; }

int klin_gd32v_http_last_content_length(void) {
  return g_last_content_length;
}

static int parse_http_url(const char *url, int *https, char *host, size_t host_cap,
                          int *port, const char **path_out) {
  const char *p = url;
  *https = 0;
  *port = 80;
  if (strncmp(p, "https://", 8) == 0) {
    *https = 1;
    *port = 443;
    p += 8;
  } else if (strncmp(p, "http://", 7) == 0) {
    p += 7;
  } else {
    return -1;
  }
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
  return 0;
}

static int parse_status_and_length(const char *headers, int header_len) {
  g_last_status = 0;
  g_last_content_length = -1;
  if (header_len < 12) {
    return -1;
  }
  if (strncmp(headers, "HTTP/", 5) != 0) {
    return -1;
  }
  const char *sp = strchr(headers, ' ');
  if (sp == NULL || sp >= headers + header_len) {
    return -1;
  }
  g_last_status = atoi(sp + 1);
  const char *p = headers;
  const char *end = headers + header_len;
  while (p + 16 < end) {
    if ((p[0] == '\n') &&
        (strncmp(p + 1, "Content-Length:", 15) == 0 ||
         strncmp(p + 1, "content-length:", 15) == 0)) {
      g_last_content_length = atoi(p + 16);
      break;
    }
    p++;
  }
  return 0;
}

#if KLIN_GD32V_HTTP_HAVE_LWIP

static int http_exchange_clear(const char *host, int port, const char *req,
                               char *out_body, int out_cap) {
  struct addrinfo hints;
  struct addrinfo *res = NULL;
  char port_str[16];
  int fd = -1;
  int n;
  char hdr[2048];
  int hdr_len = 0;
  int body_len = 0;
  int header_done = 0;

  memset(&hints, 0, sizeof(hints));
  hints.ai_family = AF_INET;
  hints.ai_socktype = SOCK_STREAM;
  snprintf(port_str, sizeof(port_str), "%d", port);
  if (getaddrinfo(host, port_str, &hints, &res) != 0 || res == NULL) {
    return -1;
  }
  fd = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
  if (fd < 0) {
    freeaddrinfo(res);
    return -1;
  }
  if (connect(fd, res->ai_addr, res->ai_addrlen) != 0) {
    freeaddrinfo(res);
    close(fd);
    return -1;
  }
  freeaddrinfo(res);

  n = (int)strlen(req);
  if (write(fd, req, (size_t)n) != n) {
    close(fd);
    return -1;
  }

  for (;;) {
    char tmp[512];
    int r = (int)read(fd, tmp, sizeof(tmp));
    if (r <= 0) {
      break;
    }
    if (!header_done) {
      int copy = r;
      if (hdr_len + copy > (int)sizeof(hdr)) {
        copy = (int)sizeof(hdr) - hdr_len;
      }
      if (copy > 0) {
        memcpy(hdr + hdr_len, tmp, (size_t)copy);
        hdr_len += copy;
      }
      char *sep = NULL;
      for (int i = 0; i + 3 < hdr_len; i++) {
        if (hdr[i] == '\r' && hdr[i + 1] == '\n' && hdr[i + 2] == '\r' &&
            hdr[i + 3] == '\n') {
          sep = hdr + i;
          break;
        }
      }
      if (sep != NULL) {
        int hlen = (int)(sep - hdr);
        parse_status_and_length(hdr, hlen);
        header_done = 1;
        int after = hdr_len - (hlen + 4);
        if (after > 0 && out_cap > 0) {
          int take = after;
          if (take > out_cap) {
            take = out_cap;
          }
          memcpy(out_body, sep + 4, (size_t)take);
          body_len = take;
        }
        if (r > copy) {
          /* unread bytes in tmp beyond hdr buffer — rare; ignore overflow */
        }
      }
    } else if (out_cap > 0 && body_len < out_cap) {
      int take = r;
      if (body_len + take > out_cap) {
        take = out_cap - body_len;
      }
      memcpy(out_body + body_len, tmp, (size_t)take);
      body_len += take;
    }
  }
  close(fd);
  if (!header_done) {
    return -1;
  }
  if (out_cap > 0) {
    if (body_len < out_cap) {
      out_body[body_len] = '\0';
    } else if (out_cap > 0) {
      out_body[out_cap - 1] = '\0';
    }
  }
  return body_len;
}

static int build_req(char *req, size_t req_cap, const char *method, const char *path,
                     const char *host, const char *body, int body_len) {
  if (body != NULL && body_len > 0) {
    return snprintf(req, req_cap,
                    "%s %s HTTP/1.0\r\nHost: %s\r\nConnection: close\r\n"
                    "Content-Length: %d\r\n\r\n",
                    method, path, host, body_len);
  }
  return snprintf(req, req_cap,
                  "%s %s HTTP/1.0\r\nHost: %s\r\nConnection: close\r\n\r\n",
                  method, path, host);
}

int klin_gd32v_http_get(const char *url, char *out_body, int out_cap) {
  char host[128];
  int https = 0;
  int port = 80;
  const char *path = "/";
  char req[512];
  int n;

  g_last_status = 0;
  g_last_content_length = -1;
  if (url == NULL || out_body == NULL || out_cap <= 0) {
    return -1;
  }
  if (parse_http_url(url, &https, host, sizeof(host), &port, &path) != 0) {
    return -1;
  }
  if (https) {
    return -1;
  }
  n = build_req(req, sizeof(req), "GET", path, host, NULL, 0);
  if (n <= 0 || n >= (int)sizeof(req)) {
    return -1;
  }
  return http_exchange_clear(host, port, req, out_body, out_cap);
}

int klin_gd32v_http_post(const char *url, const void *body, int body_len,
                         char *out_body, int out_cap) {
  char host[128];
  int https = 0;
  int port = 80;
  const char *path = "/";
  char req[768];
  int n;
  char *full = NULL;
  int full_len;
  int got;
  const char *body_c = (const char *)body;

  g_last_status = 0;
  g_last_content_length = -1;
  if (url == NULL || out_body == NULL || out_cap <= 0) {
    return -1;
  }
  if (body_c == NULL) {
    body_c = "";
    body_len = 0;
  }
  if (body_len < 0) {
    return -1;
  }
  if (parse_http_url(url, &https, host, sizeof(host), &port, &path) != 0) {
    return -1;
  }
  if (https) {
    return -1;
  }
  n = build_req(req, sizeof(req), "POST", path, host, body_c, body_len);
  if (n <= 0 || n >= (int)sizeof(req)) {
    return -1;
  }
  full_len = n + body_len;
  full = (char *)malloc((size_t)full_len + 1);
  if (full == NULL) {
    return -1;
  }
  memcpy(full, req, (size_t)n);
  if (body_len > 0) {
    memcpy(full + n, body_c, (size_t)body_len);
  }
  full[full_len] = '\0';
  got = http_exchange_clear(host, port, full, out_body, out_cap);
  free(full);
  return got;
}

#if KLIN_GD32V_HTTP_HAVE_MBEDTLS

typedef struct {
  int fd;
} klin_gd32v_http_bio_t;

static int bio_send(void *ctx, const unsigned char *buf, size_t len) {
  klin_gd32v_http_bio_t *b = (klin_gd32v_http_bio_t *)ctx;
  int n = (int)write(b->fd, buf, len);
  if (n < 0) {
    return MBEDTLS_ERR_NET_SEND_FAILED;
  }
  return n;
}

static int bio_recv(void *ctx, unsigned char *buf, size_t len) {
  klin_gd32v_http_bio_t *b = (klin_gd32v_http_bio_t *)ctx;
  int n = (int)read(b->fd, buf, len);
  if (n < 0) {
    return MBEDTLS_ERR_NET_RECV_FAILED;
  }
  if (n == 0) {
    return MBEDTLS_ERR_SSL_PEER_CLOSE_NOTIFY;
  }
  return n;
}

static int http_exchange_tls(const char *host, int port, const char *ca_pem,
                             const char *req, char *out_body, int out_cap) {
  mbedtls_entropy_context entropy;
  mbedtls_ctr_drbg_context ctr_drbg;
  mbedtls_ssl_context ssl;
  mbedtls_ssl_config conf;
  mbedtls_x509_crt cacert;
  klin_gd32v_http_bio_t bio;
  struct sockaddr_in addr;
  char hdr[2048];
  int hdr_len = 0;
  int body_len = 0;
  int header_done = 0;
  int ret = -1;
  int n;

  memset(&addr, 0, sizeof(addr));
  bio.fd = -1;

  mbedtls_entropy_init(&entropy);
  mbedtls_ctr_drbg_init(&ctr_drbg);
  mbedtls_ssl_init(&ssl);
  mbedtls_ssl_config_init(&conf);
  mbedtls_x509_crt_init(&cacert);

  if (mbedtls_ctr_drbg_seed(&ctr_drbg, mbedtls_entropy_func, &entropy, NULL, 0) !=
      0) {
    goto done;
  }
  if (mbedtls_x509_crt_parse(&cacert, (const unsigned char *)ca_pem,
                             strlen(ca_pem) + 1) != 0) {
    goto done;
  }
  if (mbedtls_ssl_config_defaults(&conf, MBEDTLS_SSL_IS_CLIENT,
                                  MBEDTLS_SSL_TRANSPORT_STREAM,
                                  MBEDTLS_SSL_PRESET_DEFAULT) != 0) {
    goto done;
  }
  mbedtls_ssl_conf_authmode(&conf, MBEDTLS_SSL_VERIFY_REQUIRED);
  mbedtls_ssl_conf_ca_chain(&conf, &cacert, NULL);
  mbedtls_ssl_conf_rng(&conf, mbedtls_ctr_drbg_random, &ctr_drbg);
  if (mbedtls_ssl_setup(&ssl, &conf) != 0) {
    goto done;
  }
  if (mbedtls_ssl_set_hostname(&ssl, host) != 0) {
    goto done;
  }

  bio.fd = socket(AF_INET, SOCK_STREAM, 0);
  if (bio.fd < 0) {
    goto done;
  }
  addr.sin_family = AF_INET;
  addr.sin_port = htons((uint16_t)port);
  {
    struct addrinfo hints;
    struct addrinfo *res = NULL;
    char port_str[16];
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;
    snprintf(port_str, sizeof(port_str), "%d", port);
    if (getaddrinfo(host, port_str, &hints, &res) != 0 || res == NULL) {
      goto done;
    }
    memcpy(&addr, res->ai_addr, sizeof(addr));
    freeaddrinfo(res);
  }
  if (connect(bio.fd, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
    goto done;
  }
  mbedtls_ssl_set_bio(&ssl, &bio, bio_send, bio_recv, NULL);
  while ((n = mbedtls_ssl_handshake(&ssl)) != 0) {
    if (n != MBEDTLS_ERR_SSL_WANT_READ && n != MBEDTLS_ERR_SSL_WANT_WRITE) {
      goto done;
    }
  }

  n = (int)strlen(req);
  {
    int off = 0;
    while (off < n) {
      int w = mbedtls_ssl_write(&ssl, (const unsigned char *)req + off,
                                (size_t)(n - off));
      if (w <= 0) {
        goto done;
      }
      off += w;
    }
  }

  for (;;) {
    unsigned char tmp[512];
    int r = mbedtls_ssl_read(&ssl, tmp, sizeof(tmp));
    if (r == MBEDTLS_ERR_SSL_WANT_READ || r == MBEDTLS_ERR_SSL_WANT_WRITE) {
      continue;
    }
    if (r == MBEDTLS_ERR_SSL_PEER_CLOSE_NOTIFY || r == 0) {
      break;
    }
    if (r < 0) {
      break;
    }
    if (!header_done) {
      int copy = r;
      if (hdr_len + copy > (int)sizeof(hdr)) {
        copy = (int)sizeof(hdr) - hdr_len;
      }
      if (copy > 0) {
        memcpy(hdr + hdr_len, tmp, (size_t)copy);
        hdr_len += copy;
      }
      char *sep = NULL;
      for (int i = 0; i + 3 < hdr_len; i++) {
        if (hdr[i] == '\r' && hdr[i + 1] == '\n' && hdr[i + 2] == '\r' &&
            hdr[i + 3] == '\n') {
          sep = hdr + i;
          break;
        }
      }
      if (sep != NULL) {
        int hlen = (int)(sep - hdr);
        parse_status_and_length(hdr, hlen);
        header_done = 1;
        int after = hdr_len - (hlen + 4);
        if (after > 0 && out_cap > 0) {
          int take = after;
          if (take > out_cap) {
            take = out_cap;
          }
          memcpy(out_body, sep + 4, (size_t)take);
          body_len = take;
        }
      }
    } else if (out_cap > 0 && body_len < out_cap) {
      int take = r;
      if (body_len + take > out_cap) {
        take = out_cap - body_len;
      }
      memcpy(out_body + body_len, tmp, (size_t)take);
      body_len += take;
    }
  }

  if (header_done) {
    if (out_cap > 0) {
      if (body_len < out_cap) {
        out_body[body_len] = '\0';
      } else {
        out_body[out_cap - 1] = '\0';
      }
    }
    ret = body_len;
  }

done:
  mbedtls_ssl_free(&ssl);
  mbedtls_ssl_config_free(&conf);
  mbedtls_x509_crt_free(&cacert);
  mbedtls_ctr_drbg_free(&ctr_drbg);
  mbedtls_entropy_free(&entropy);
  if (bio.fd >= 0) {
    close(bio.fd);
  }
  return ret;
}

int klin_gd32v_http_get_tls_pem(const char *url, const char *ca_pem,
                                char *out_body, int out_cap) {
  char host[128];
  int https = 0;
  int port = 443;
  const char *path = "/";
  char req[512];
  int n;

  g_last_status = 0;
  g_last_content_length = -1;
  if (url == NULL || ca_pem == NULL || out_body == NULL || out_cap <= 0) {
    return -1;
  }
  if (parse_http_url(url, &https, host, sizeof(host), &port, &path) != 0) {
    return -1;
  }
  if (!https) {
    return -1;
  }
  n = build_req(req, sizeof(req), "GET", path, host, NULL, 0);
  if (n <= 0 || n >= (int)sizeof(req)) {
    return -1;
  }
  return http_exchange_tls(host, port, ca_pem, req, out_body, out_cap);
}

int klin_gd32v_http_post_tls_pem(const char *url, const char *ca_pem,
                                 const void *body, int body_len, char *out_body,
                                 int out_cap) {
  char host[128];
  int https = 0;
  int port = 443;
  const char *path = "/";
  char req[768];
  int n;
  char *full = NULL;
  int full_len;
  int got;
  const char *body_c = (const char *)body;

  g_last_status = 0;
  g_last_content_length = -1;
  if (url == NULL || ca_pem == NULL || out_body == NULL || out_cap <= 0) {
    return -1;
  }
  if (body_c == NULL) {
    body_c = "";
    body_len = 0;
  }
  if (body_len < 0) {
    return -1;
  }
  if (parse_http_url(url, &https, host, sizeof(host), &port, &path) != 0) {
    return -1;
  }
  if (!https) {
    return -1;
  }
  n = build_req(req, sizeof(req), "POST", path, host, body_c, body_len);
  if (n <= 0 || n >= (int)sizeof(req)) {
    return -1;
  }
  full_len = n + body_len;
  full = (char *)malloc((size_t)full_len + 1);
  if (full == NULL) {
    return -1;
  }
  memcpy(full, req, (size_t)n);
  if (body_len > 0) {
    memcpy(full + n, body_c, (size_t)body_len);
  }
  full[full_len] = '\0';
  got = http_exchange_tls(host, port, ca_pem, full, out_body, out_cap);
  free(full);
  return got;
}

#else /* !HAVE_MBEDTLS */

int klin_gd32v_http_get_tls_pem(const char *url, const char *ca_pem,
                                char *out_body, int out_cap) {
  (void)url;
  (void)ca_pem;
  (void)out_body;
  (void)out_cap;
  g_last_status = 0;
  g_last_content_length = -1;
  return -1;
}

int klin_gd32v_http_post_tls_pem(const char *url, const char *ca_pem,
                                 const void *body, int body_len, char *out_body,
                                 int out_cap) {
  (void)url;
  (void)ca_pem;
  (void)body;
  (void)body_len;
  (void)out_body;
  (void)out_cap;
  g_last_status = 0;
  g_last_content_length = -1;
  return -1;
}

#endif /* HAVE_MBEDTLS */

#else /* !HAVE_LWIP — host stubs for `klin test` */

int klin_gd32v_http_get(const char *url, char *out_body, int out_cap) {
  (void)url;
  g_last_status = 200;
  g_last_content_length = 2;
  if (out_body == NULL || out_cap < 3) {
    return -1;
  }
  out_body[0] = 'o';
  out_body[1] = 'k';
  out_body[2] = '\0';
  return 2;
}

int klin_gd32v_http_post(const char *url, const void *body, int body_len,
                         char *out_body, int out_cap) {
  (void)url;
  (void)body;
  (void)body_len;
  return klin_gd32v_http_get("http://stub/", out_body, out_cap);
}

int klin_gd32v_http_get_tls_pem(const char *url, const char *ca_pem,
                                char *out_body, int out_cap) {
  (void)ca_pem;
  return klin_gd32v_http_get(url, out_body, out_cap);
}

int klin_gd32v_http_post_tls_pem(const char *url, const char *ca_pem,
                                 const void *body, int body_len, char *out_body,
                                 int out_cap) {
  (void)ca_pem;
  return klin_gd32v_http_post(url, body, body_len, out_body, out_cap);
}

#endif /* HAVE_LWIP */
