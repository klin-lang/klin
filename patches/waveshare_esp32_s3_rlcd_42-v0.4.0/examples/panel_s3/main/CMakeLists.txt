# Klin emit must run before configure (see ../Makefile `emit`).
set(KLIN_C "${CMAKE_SOURCE_DIR}/out/panel.c")
set(KLIN_LINK "${CMAKE_SOURCE_DIR}/out/panel.link")

if(NOT EXISTS "${KLIN_C}")
    message(FATAL_ERROR
        "Missing ${KLIN_C}. From examples/panel_s3 run: make emit KLIN=...")
endif()

set(KLIN_EXTRA_SRCS "")
set(KLIN_EXTRA_INCS "${CMAKE_SOURCE_DIR}/out")
if(EXISTS "${KLIN_LINK}")
    file(STRINGS "${KLIN_LINK}" KLIN_LINK_LINES)
    foreach(line IN LISTS KLIN_LINK_LINES)
        if(line MATCHES "\\.c$")
            list(APPEND KLIN_EXTRA_SRCS "${line}")
            get_filename_component(_dir "${line}" DIRECTORY)
            list(APPEND KLIN_EXTRA_INCS "${_dir}")
        endif()
    endforeach()
endif()

list(REMOVE_DUPLICATES KLIN_EXTRA_INCS)

idf_component_register(
    SRCS "app_main.c" "${KLIN_C}" ${KLIN_EXTRA_SRCS}
    INCLUDE_DIRS "." ${KLIN_EXTRA_INCS}
    REQUIRES driver esp_adc fatfs sdmmc
)
