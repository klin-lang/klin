set(KLIN_C "${CMAKE_SOURCE_DIR}/out/panel.c")
set(ST_C "${CMAKE_SOURCE_DIR}/../../waveshare_esp32_s3_rlcd_42/st7305_idf.c")

if(NOT EXISTS "${KLIN_C}")
    message(FATAL_ERROR
        "Missing ${KLIN_C}. From examples/panel_s3 run: make emit KLIN=...")
endif()

idf_component_register(
    SRCS "app_main.c" "${KLIN_C}" "${ST_C}"
    INCLUDE_DIRS "." "${CMAKE_SOURCE_DIR}/out" "${CMAKE_SOURCE_DIR}/../../waveshare_esp32_s3_rlcd_42"
    REQUIRES driver esp_adc
)
