set(KLIN_C "${CMAKE_SOURCE_DIR}/out/main.c")

if(NOT EXISTS "${KLIN_C}")
    message(FATAL_ERROR
        "Missing ${KLIN_C}. From project root run: make emit KLIN=...")
endif()

idf_component_register(
    SRCS "app_main.c" "${KLIN_C}"
    INCLUDE_DIRS "." "${CMAKE_SOURCE_DIR}/out"
)
