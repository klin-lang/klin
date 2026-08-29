# Klin emit must run before configure (see ../Makefile `emit` target).
set(KLIN_C "${CMAKE_SOURCE_DIR}/out/peer.c")
set(NOW_C "${CMAKE_SOURCE_DIR}/../../espnow/now_idf.c")

if(NOT EXISTS "${KLIN_C}")
    message(FATAL_ERROR
        "Missing ${KLIN_C}. From examples/peer_s3 run: make emit KLIN=...")
endif()

idf_component_register(
    SRCS "app_main.c" "${KLIN_C}" "${NOW_C}"
    INCLUDE_DIRS "." "${CMAKE_SOURCE_DIR}/out" "${CMAKE_SOURCE_DIR}/../../espnow"
    REQUIRES nvs_flash esp_wifi esp_netif esp_event
)
