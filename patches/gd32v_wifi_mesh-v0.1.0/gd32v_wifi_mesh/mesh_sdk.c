#include "mesh_sdk.h"

#include <stdint.h>
#include <string.h>

#if defined(__has_include)
#if __has_include("wifi_mesh_smart.h")
#include "wifi_mesh_smart.h"
#define KLIN_GD32V_MESH_HAVE_SDK 1
#else
#define KLIN_GD32V_MESH_HAVE_SDK 0
#endif
#else
#define KLIN_GD32V_MESH_HAVE_SDK 0
#endif

/* SDK status values mirrored for host stubs / docs. */
#define KLIN_MESH_STATUS_INIT 0
#define KLIN_MESH_STATUS_JOINED 5 /* STA_CONNECTED_SOFTAP_STARTED */
#define KLIN_MESH_ROLE_ROOT 0
#define KLIN_MESH_ROLE_ROUTER 1
#define KLIN_MESH_ROLE_LEAF 2

static int g_started = 0;

#if KLIN_GD32V_MESH_HAVE_SDK

/* Exported by MSDK wifi_netlink / mesh sources when CONFIG_WIFI_MESH_SMART. */
extern wifi_mesh_smart_info_t mesh_smart_info;

int klin_gd32v_mesh_init(void) {
  wifi_mesh_smart_network_init();
  g_started = 1;
  return 0;
}

int klin_gd32v_mesh_config_rootap(const char *ssid, const char *password) {
  if (ssid == NULL || password == NULL) {
    return -1;
  }
  if (wifi_mesh_smart_config_rootap_info((char *)ssid, (char *)password) != 0) {
    return -1;
  }
  return 0;
}

int klin_gd32v_mesh_softap_stop(void) {
  if (wifi_mesh_smart_softap_stop() != 0) {
    return -1;
  }
  return 0;
}

int klin_gd32v_mesh_started(void) {
  return g_started || (mesh_smart_info.mesh_smart_network_enabled ? 1 : 0);
}

int klin_gd32v_mesh_joined(void) {
  return mesh_smart_info.status.node_status ==
                 MESH_SMART_STATUS_STA_CONNECTED_SOFTAP_STARTED
             ? 1
             : 0;
}

int klin_gd32v_mesh_status(void) {
  return (int)mesh_smart_info.status.node_status;
}

int klin_gd32v_mesh_role(void) {
  return (int)mesh_smart_info.cfg.mesh_role_type;
}

int klin_gd32v_mesh_level(void) {
  return (int)mesh_smart_info.status.current_level;
}

int klin_gd32v_mesh_node_id(void) {
  return (int)mesh_smart_info.status.node_id;
}

#else /* host stubs */

static int g_status = KLIN_MESH_STATUS_INIT;
static int g_role = KLIN_MESH_ROLE_ROUTER;
static int g_level = 0;
static int g_node_id = 0;
static char g_root_ssid[33];
static char g_root_pass[65];

int klin_gd32v_mesh_init(void) {
  g_started = 1;
  g_status = KLIN_MESH_STATUS_INIT;
  g_role = KLIN_MESH_ROLE_ROUTER;
  g_level = 0;
  g_node_id = 0;
  return 0;
}

int klin_gd32v_mesh_config_rootap(const char *ssid, const char *password) {
  size_t n;
  if (!g_started || ssid == NULL || password == NULL) {
    return -1;
  }
  n = strlen(ssid);
  if (n == 0 || n >= sizeof(g_root_ssid)) {
    return -1;
  }
  n = strlen(password);
  if (n >= sizeof(g_root_pass)) {
    return -1;
  }
  memcpy(g_root_ssid, ssid, strlen(ssid) + 1);
  memcpy(g_root_pass, password, strlen(password) + 1);
  /* Host stub: pretend provisioning succeeded → joined ROOT at level 1. */
  g_role = KLIN_MESH_ROLE_ROOT;
  g_status = KLIN_MESH_STATUS_JOINED;
  g_level = 1;
  g_node_id = 1;
  return 0;
}

int klin_gd32v_mesh_softap_stop(void) {
  if (!g_started) {
    return -1;
  }
  if (g_status == KLIN_MESH_STATUS_JOINED) {
    g_status = KLIN_MESH_STATUS_INIT;
  }
  return 0;
}

int klin_gd32v_mesh_started(void) { return g_started; }

int klin_gd32v_mesh_joined(void) {
  return g_status == KLIN_MESH_STATUS_JOINED ? 1 : 0;
}

int klin_gd32v_mesh_status(void) {
  if (!g_started) {
    return -1;
  }
  return g_status;
}

int klin_gd32v_mesh_role(void) {
  if (!g_started) {
    return -1;
  }
  return g_role;
}

int klin_gd32v_mesh_level(void) {
  if (!g_started) {
    return 0;
  }
  return g_level;
}

int klin_gd32v_mesh_node_id(void) {
  if (!g_started) {
    return 0;
  }
  return g_node_id;
}

#endif /* HAVE_SDK */
