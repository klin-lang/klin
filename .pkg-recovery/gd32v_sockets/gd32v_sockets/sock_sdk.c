/* LwIP BSD sockets for Klin apps on GD32VW55x (GigaDevice Wi‑Fi BLE SDK).
 * Thin wrappers; buffers are caller-owned. Netif must already be up (gd32v_wifi).
 * Host path: stubs when lwip/sockets.h is not on the include path (klin test).
 */
#include "sock_sdk.h"

#include <stdio.h>
#include <string.h>

#if defined(__has_include)
#if __has_include("lwip/sockets.h")
#define KLIN_GD32V_SOCK_HAVE_LWIP 1
#endif
#endif

#ifdef KLIN_GD32V_SOCK_HAVE_LWIP
#include "lwip/err.h"
#include "lwip/netdb.h"
#include "lwip/sockets.h"

static int klin_gd32v_sock_port_ok(int port)
{
    return port >= 0 && port <= 65535;
}

static int klin_gd32v_sock_set_reuse(int fd)
{
    int yes = 1;
    return setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));
}

int klin_gd32v_sock_tcp(void)
{
    int fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (fd < 0) {
        return -1;
    }
    (void)klin_gd32v_sock_set_reuse(fd);
    return fd;
}

int klin_gd32v_sock_udp(void)
{
    int fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (fd < 0) {
        return -1;
    }
    (void)klin_gd32v_sock_set_reuse(fd);
    return fd;
}

int klin_gd32v_sock_connect_ipv4(int fd, uint32_t ip, int port)
{
    struct sockaddr_in addr;

    if (fd < 0 || !klin_gd32v_sock_port_ok(port)) {
        return -1;
    }
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons((uint16_t)port);
    addr.sin_addr.s_addr = ip;
    if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
        return -1;
    }
    return 0;
}

int klin_gd32v_sock_connect_host(int fd, const char *host, int port)
{
    struct addrinfo hints;
    struct addrinfo *res = NULL;
    struct addrinfo *p;
    char portbuf[8];
    int err;
    int rc = -1;

    if (fd < 0 || host == NULL || host[0] == '\0' || !klin_gd32v_sock_port_ok(port)) {
        return -1;
    }

    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;
    snprintf(portbuf, sizeof(portbuf), "%u", (unsigned)port);

    err = getaddrinfo(host, portbuf, &hints, &res);
    if (err != 0 || res == NULL) {
        return -1;
    }

    for (p = res; p != NULL; p = p->ai_next) {
        if (connect(fd, p->ai_addr, p->ai_addrlen) == 0) {
            rc = 0;
            break;
        }
    }
    freeaddrinfo(res);
    return rc;
}

int klin_gd32v_sock_bind(int fd, int port)
{
    struct sockaddr_in addr;

    if (fd < 0 || !klin_gd32v_sock_port_ok(port)) {
        return -1;
    }
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons((uint16_t)port);
    addr.sin_addr.s_addr = htonl(INADDR_ANY);
    if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
        return -1;
    }
    return 0;
}

int klin_gd32v_sock_listen(int fd, int backlog)
{
    if (fd < 0) {
        return -1;
    }
    if (backlog < 1) {
        backlog = 1;
    }
    if (listen(fd, backlog) != 0) {
        return -1;
    }
    return 0;
}

int klin_gd32v_sock_accept(int fd)
{
    struct sockaddr_in addr;
    socklen_t len = sizeof(addr);
    int cfd;

    if (fd < 0) {
        return -1;
    }
    memset(&addr, 0, sizeof(addr));
    cfd = accept(fd, (struct sockaddr *)&addr, &len);
    return cfd;
}

int klin_gd32v_sock_send(int fd, const void *buf, int len)
{
    int n;

    if (fd < 0 || buf == NULL || len < 0) {
        return -1;
    }
    n = (int)send(fd, buf, (size_t)len, 0);
    return n;
}

int klin_gd32v_sock_recv(int fd, void *buf, int max_len)
{
    int n;

    if (fd < 0 || buf == NULL || max_len <= 0) {
        return -1;
    }
    n = (int)recv(fd, buf, (size_t)max_len, 0);
    return n;
}

int klin_gd32v_sock_sendto(int fd, const void *buf, int len, uint32_t ip, int port)
{
    struct sockaddr_in addr;
    int n;

    if (fd < 0 || buf == NULL || len < 0 || !klin_gd32v_sock_port_ok(port)) {
        return -1;
    }
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons((uint16_t)port);
    addr.sin_addr.s_addr = ip;
    n = (int)sendto(fd, buf, (size_t)len, 0, (struct sockaddr *)&addr, sizeof(addr));
    return n;
}

int klin_gd32v_sock_recvfrom(int fd, void *buf, int max_len, uint32_t *out_ip,
                             int *out_port)
{
    struct sockaddr_in addr;
    socklen_t alen = sizeof(addr);
    int n;

    if (fd < 0 || buf == NULL || max_len <= 0) {
        return -1;
    }
    memset(&addr, 0, sizeof(addr));
    n = (int)recvfrom(fd, buf, (size_t)max_len, 0, (struct sockaddr *)&addr, &alen);
    if (n >= 0) {
        if (out_ip != NULL) {
            *out_ip = (uint32_t)addr.sin_addr.s_addr;
        }
        if (out_port != NULL) {
            *out_port = (int)ntohs(addr.sin_port);
        }
    }
    return n;
}

int klin_gd32v_sock_close(int fd)
{
    if (fd < 0) {
        return -1;
    }
    if (close(fd) != 0) {
        return -1;
    }
    return 0;
}

int klin_gd32v_sock_set_recv_timeout_ms(int fd, int ms)
{
    struct timeval tv;

    if (fd < 0 || ms < 0) {
        return -1;
    }
    tv.tv_sec = ms / 1000;
    tv.tv_usec = (ms % 1000) * 1000;
    if (setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv)) != 0) {
        return -1;
    }
    return 0;
}

#else /* host stubs */

static int s_next_fd = 100;
static int s_open[16];
static int s_nopen;

static int klin_gd32v_sock_track(int fd)
{
    if (s_nopen >= 16) {
        return -1;
    }
    s_open[s_nopen++] = fd;
    return fd;
}

static int klin_gd32v_sock_tracked(int fd)
{
    int i;

    for (i = 0; i < s_nopen; i++) {
        if (s_open[i] == fd) {
            return 1;
        }
    }
    return 0;
}

static void klin_gd32v_sock_untrack(int fd)
{
    int i;
    int j;

    for (i = 0; i < s_nopen; i++) {
        if (s_open[i] == fd) {
            for (j = i; j < s_nopen - 1; j++) {
                s_open[j] = s_open[j + 1];
            }
            s_nopen--;
            return;
        }
    }
}

int klin_gd32v_sock_tcp(void)
{
    return klin_gd32v_sock_track(s_next_fd++);
}

int klin_gd32v_sock_udp(void)
{
    return klin_gd32v_sock_track(s_next_fd++);
}

int klin_gd32v_sock_connect_ipv4(int fd, uint32_t ip, int port)
{
    (void)ip;
    if (!klin_gd32v_sock_tracked(fd) || port < 0 || port > 65535) {
        return -1;
    }
    return 0;
}

int klin_gd32v_sock_connect_host(int fd, const char *host, int port)
{
    if (!klin_gd32v_sock_tracked(fd) || host == NULL || host[0] == '\0' ||
        port < 0 || port > 65535) {
        return -1;
    }
    return 0;
}

int klin_gd32v_sock_bind(int fd, int port)
{
    if (!klin_gd32v_sock_tracked(fd) || port < 0 || port > 65535) {
        return -1;
    }
    return 0;
}

int klin_gd32v_sock_listen(int fd, int backlog)
{
    (void)backlog;
    if (!klin_gd32v_sock_tracked(fd)) {
        return -1;
    }
    return 0;
}

int klin_gd32v_sock_accept(int fd)
{
    if (!klin_gd32v_sock_tracked(fd)) {
        return -1;
    }
    return klin_gd32v_sock_track(s_next_fd++);
}

int klin_gd32v_sock_send(int fd, const void *buf, int len)
{
    if (!klin_gd32v_sock_tracked(fd) || buf == NULL || len < 0) {
        return -1;
    }
    return len;
}

int klin_gd32v_sock_recv(int fd, void *buf, int max_len)
{
    unsigned char *b;

    if (!klin_gd32v_sock_tracked(fd) || buf == NULL || max_len <= 0) {
        return -1;
    }
    b = (unsigned char *)buf;
    b[0] = (unsigned char)'o';
    if (max_len > 1) {
        b[1] = (unsigned char)'k';
        return 2;
    }
    return 1;
}

int klin_gd32v_sock_sendto(int fd, const void *buf, int len, uint32_t ip, int port)
{
    (void)ip;
    if (!klin_gd32v_sock_tracked(fd) || buf == NULL || len < 0 || port < 0 ||
        port > 65535) {
        return -1;
    }
    return len;
}

int klin_gd32v_sock_recvfrom(int fd, void *buf, int max_len, uint32_t *out_ip,
                             int *out_port)
{
    unsigned char *b;

    if (!klin_gd32v_sock_tracked(fd) || buf == NULL || max_len <= 0) {
        return -1;
    }
    b = (unsigned char *)buf;
    b[0] = (unsigned char)'u';
    if (out_ip != NULL) {
        *out_ip = 192u | (168u << 8) | (1u << 16) | (1u << 24);
    }
    if (out_port != NULL) {
        *out_port = 9000;
    }
    return 1;
}

int klin_gd32v_sock_close(int fd)
{
    if (!klin_gd32v_sock_tracked(fd)) {
        return -1;
    }
    klin_gd32v_sock_untrack(fd);
    return 0;
}

int klin_gd32v_sock_set_recv_timeout_ms(int fd, int ms)
{
    if (!klin_gd32v_sock_tracked(fd) || ms < 0) {
        return -1;
    }
    return 0;
}

#endif
