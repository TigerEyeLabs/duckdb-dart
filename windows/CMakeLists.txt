cmake_minimum_required(VERSION 3.14)
set(CMAKE_VERBOSE_MAKEFILE ON)

set(PROJECT_NAME "dart_duckdb")
project(${PROJECT_NAME} LANGUAGES CXX)

set(PLUGIN_NAME "dart_duckdb_plugin")

list(APPEND PLUGIN_SOURCES
  "dart_duckdb_plugin.cpp"
  "dart_duckdb_plugin.h"
)

add_library(${PLUGIN_NAME} SHARED
  "include/dart_duckdb/dart_duckdb_plugin_c_api.h"
  "dart_duckdb_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

set(PREBUILT_RELEASE_DUCKDB_DLL "${CMAKE_CURRENT_SOURCE_DIR}/Libraries/release/duckdb.dll")
set(DUCKDB_DOWNLOAD_URL "https://github.com/duckdb/duckdb/releases/download/v1.4.2/libduckdb-windows-amd64.zip")
set(DUCKDB_DOWNLOAD_DIR "${CMAKE_CURRENT_BINARY_DIR}/duckdb_download")
set(DUCKDB_ZIP_FILE "${DUCKDB_DOWNLOAD_DIR}/libduckdb-windows-amd64.zip")

if(NOT EXISTS ${PREBUILT_RELEASE_DUCKDB_DLL})
  message(STATUS "DuckDB DLL not found. Downloading...")
  file(DOWNLOAD ${DUCKDB_DOWNLOAD_URL} ${DUCKDB_ZIP_FILE} SHOW_PROGRESS STATUS download_status)
  list(GET download_status 0 status_code)
  if(NOT status_code EQUAL 0)
    message(FATAL_ERROR "Failed to download DuckDB DLL")
  endif()
  message(STATUS "Download completed successfully")

  message(STATUS "Extracting DuckDB DLL...")
  file(MAKE_DIRECTORY ${DUCKDB_DOWNLOAD_DIR}/extracted)
  execute_process(
    COMMAND ${CMAKE_COMMAND} -E tar xzf ${DUCKDB_ZIP_FILE}
    WORKING_DIRECTORY ${DUCKDB_DOWNLOAD_DIR}/extracted
    RESULT_VARIABLE extract_result
  )
  if(NOT extract_result EQUAL 0)
    message(FATAL_ERROR "Failed to extract DuckDB DLL")
  endif()
  message(STATUS "Extraction completed successfully")

  message(STATUS "Copying DuckDB DLL to Libraries/release directory...")
  file(COPY ${DUCKDB_DOWNLOAD_DIR}/extracted/duckdb.dll DESTINATION ${CMAKE_CURRENT_SOURCE_DIR}/Libraries/release/)
  set(PREBUILT_RELEASE_DUCKDB_DLL "${CMAKE_CURRENT_SOURCE_DIR}/Libraries/release/duckdb.dll")
  message(STATUS "DuckDB DLL copied to: ${PREBUILT_RELEASE_DUCKDB_DLL}")
else()
  message(STATUS "DuckDB DLL already exists at: ${PREBUILT_RELEASE_DUCKDB_DLL}")
endif()

file(GLOB DUCKDB_DLL "${PREBUILT_RELEASE_DUCKDB_DLL}")

add_library(duckdb SHARED IMPORTED)
set_property(TARGET duckdb PROPERTY IMPORTED_LOCATION "${DUCKDB_DLL}")

add_dependencies(${PLUGIN_NAME} duckdb)

get_filename_component(RELEASE_OUTPUT_DIR "${CMAKE_BINARY_DIR}/../../build/windows/runner/Release/" ABSOLUTE)

# Ensure the DLL is copied before setting it in the bundled libraries list
file(COPY ${DUCKDB_DLL} DESTINATION ${RELEASE_OUTPUT_DIR})
message(STATUS "DuckDB DLL installed to: ${RELEASE_OUTPUT_DIR}/duckdb.dll")

set(dart_duckdb_bundled_libraries
  "$<$<CONFIG:Debug>:${RELEASE_OUTPUT_DIR}/duckdb.dll>"
  "$<$<CONFIG:Release>:${RELEASE_OUTPUT_DIR}/duckdb.dll>"
  "$<$<CONFIG:Profile>:${RELEASE_OUTPUT_DIR}/duckdb.dll>"
  PARENT_SCOPE
)
