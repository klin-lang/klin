/* Thin Wi‑Fi Mesh-Smart client for Klin on GD32VW55x.
 * Engine = GigaDevice `wifi_mesh_smart` (CONFIG_WIFI_MESH_SMART).
 * Not BLE Mesh. Not ESP-NOW / ESP-IDF. Sibling of gd32v_wifi.
 * Bring up Wi‑Fi management first (e.g. gd32v_wifi.sta_init).
 * Host stubs when wifi_mesh_smart.h is absent.
 */
#pragma once

#ifdef __cplusplus
extern "C" {
#endif

/** Start Mesh-Smart self-organize (async SDK task). Returns 0 or -1. */
int klin_gd32v_mesh_init(void);

/**
 * Provision Root AP credentials (SSID / password are caller strings).
 * First-boot / SoftAP provisioning path. Returns 0 or -1.
 */
int klin_gd32v_mesh_config_rootap(const char *ssid, const char *password);

/** Stop this node's Mesh SoftAP. Returns 0 or -1. */
int klin_gd32v_mesh_softap_stop(void);

/** 1 after init (host) / when SDK mesh is enabled. */
int klin_gd32v_mesh_started(void);

/**
 * 1 when node status is STA_CONNECTED_SOFTAP_STARTED
 * (joined and SoftAP up — typical “in mesh” ready).
 */
int klin_gd32v_mesh_joined(void);

/** Current node status enum value (mesh_smart_state), or -1. */
int klin_gd32v_mesh_status(void);

/** Role: 0 ROOT, 1 ROUTER, 2 LEAF (mesh_smart_node_type_t). */
int klin_gd32v_mesh_role(void);

/** Current mesh level (1 = ROOT), or 0. */
int klin_gd32v_mesh_level(void);

/** Unique node id in the mesh, or 0. */
int klin_gd32v_mesh_node_id(void);

#ifdef __cplusplus
}
#endif
