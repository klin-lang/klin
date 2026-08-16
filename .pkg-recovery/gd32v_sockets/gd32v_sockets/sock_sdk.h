/* Thin LwIP BSD-socket helpers for Klin on GD32VW55x.
 * Does not bring up Wi‑Fi — call after gd32v_wifi has an IP.
 * Caller owns all buffers; no Klin heap.
 */
#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/** Create TCP stream socket. Returns fd >= 0, or -1. */
int klin_gd32v_sock_tcp(void);

/** Create UDP datagram socket. Returns fd >= 0, or -1. */
int klin_gd32v_sock_udp(void);

/**
 * Connect TCP fd to IPv4 (lwIP byte order) + port (host order 0..65535).
 * Returns 0 on success, else -1.
 */
int klin_gd32v_sock_connect_ipv4(int fd, uint32_t ip, int port);

/**
 * Connect TCP fd via getaddrinfo(host). Host is C string (DNS = LwIP cost).
 * Returns 0 on success, else -1.
 */
int klin_gd32v_sock_connect_host(int fd, const char *host, int port);

/** Bind fd to INADDR_ANY + port. Returns 0 or -1. */
int klin_gd32v_sock_bind(int fd, int port);

/** listen(fd, backlog). Returns 0 or -1. */
int klin_gd32v_sock_listen(int fd, int backlog);

/** accept(fd). Returns new fd >= 0, or -1. */
int klin_gd32v_sock_accept(int fd);

/** send / recv — caller buffer. Returns byte count, or -1. */
int klin_gd32v_sock_send(int fd, const void *buf, int len);
int klin_gd32v_sock_recv(int fd, void *buf, int max_len);

/**
 * UDP sendto / recvfrom. ip is lwIP byte order; port host order.
 * recvfrom writes *out_ip / *out_port when non-NULL.
 */
int klin_gd32v_sock_sendto(int fd, const void *buf, int len, uint32_t ip, int port);
int klin_gd32v_sock_recvfrom(int fd, void *buf, int max_len, uint32_t *out_ip,
                             int *out_port);

/** close(fd). Returns 0 or -1. */
int klin_gd32v_sock_close(int fd);

/** SO_RCVTIMEO in milliseconds (0 = blocking). Returns 0 or -1. */
int klin_gd32v_sock_set_recv_timeout_ms(int fd, int ms);

#ifdef __cplusplus
}
#endif
