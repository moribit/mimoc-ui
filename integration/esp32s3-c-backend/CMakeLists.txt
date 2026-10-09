cmake_minimum_required(VERSION 3.20)
# Use the unmodified ESP-IDF toolchain file, but never link a firmware/executable.
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
project(mimoc_generated_c_compile C)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
# IDF 6 moves the chip/architecture flags from toolchain-esp32s3.cmake
# into the SoC project include. Reuse that official file, without a firmware project.
if(COMMAND idf_toolchain_add_flags)
    set(CONFIG_IDF_TOOLCHAIN_GCC ON)
    set(CONFIG_IDF_TARGET_ESP32S3 ON)
    set(CONFIG_IDF_TARGET_ARCH_XTENSA ON)
    include("$ENV{IDF_PATH}/components/soc/project_include.cmake")
endif()
add_library(abi_probe OBJECT abi_probe.c)
add_library(mimoc_generated OBJECT "${MIMOC_GENERATED_C}")
target_include_directories(mimoc_generated PRIVATE "${MIMOC_ZIG_LIB}")
target_compile_options(mimoc_generated PRIVATE -std=c11 -Os -Wall -Wextra)
