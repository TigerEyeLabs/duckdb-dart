cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "dart_duckdb")
project(${PROJECT_NAME} LANGUAGES C CXX)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "dart_duckdb_plugin")

set(DUCKDB_DOWNLOAD_URL "https://github.com/duckdb/duckdb/releases/download/v1.4.2/libduckdb-linux-amd64.zip")
set(DUCKDB_DOWNLOAD_DIR "${CMAKE_CURRENT_BINARY_DIR}/duckdb_download")
set(DUCKDB_ZIP_FILE "${DUCKDB_DOWNLOAD_DIR}/libduckdb-linux-amd64.zip")
set(DUCKDB_EXTRACT_DIR "${DUCKDB_DOWNLOAD_DIR}/extracted")
set(DUCKDB_LIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/Libraries/release")
set(DUCKDB_LIB_FILE "${DUCKDB_LIB_DIR}/libduckdb.so")

if(NOT EXISTS ${DUCKDB_LIB_FILE})
  message(STATUS "DuckDB library not found. Downloading...")
  file(DOWNLOAD ${DUCKDB_DOWNLOAD_URL} ${DUCKDB_ZIP_FILE} SHOW_PROGRESS STATUS download_status)
  list(GET download_status 0 status_code)
  if(NOT status_code EQUAL 0)
    message(FATAL_ERROR "Failed to download DuckDB library")
  endif()
  message(STATUS "Download completed successfully")

  message(STATUS "Extracting DuckDB library...")
  file(MAKE_DIRECTORY ${DUCKDB_EXTRACT_DIR})
  execute_process(
    COMMAND ${CMAKE_COMMAND} -E tar xzf ${DUCKDB_ZIP_FILE}
    WORKING_DIRECTORY ${DUCKDB_EXTRACT_DIR}
    RESULT_VARIABLE extract_result
  )
  if(NOT extract_result EQUAL 0)
    message(FATAL_ERROR "Failed to extract DuckDB library")
  endif()
  message(STATUS "Extraction completed successfully")

  message(STATUS "Copying DuckDB library to Libraries/release directory...")
  file(MAKE_DIRECTORY ${DUCKDB_LIB_DIR})
  file(COPY ${DUCKDB_EXTRACT_DIR}/libduckdb.so DESTINATION ${DUCKDB_LIB_DIR})
  message(STATUS "DuckDB library copied to: ${DUCKDB_LIB_FILE}")
else()
  message(STATUS "DuckDB library already exists at: ${DUCKDB_LIB_FILE}")
endif()

add_library(${PLUGIN_NAME} SHARED
  "${CMAKE_CURRENT_SOURCE_DIR}/include/dart_duckdb/dart_duckdb_plugin.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/dart_duckdb_plugin.cc"
)

target_compile_features(${PLUGIN_NAME} PUBLIC cxx_std_14)
target_compile_options(${PLUGIN_NAME} PRIVATE "$<$<NOT:$<CONFIG:Release>>:-O3>")

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_STANDARD 14
  CXX_STANDARD_REQUIRED ON
  CXX_EXTENSIONS OFF
  CXX_VISIBILITY_PRESET hidden
)

target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)

# Link against the downloaded DuckDB library
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter ${DUCKDB_LIB_FILE})

# Install the shared DuckDB library
install(
    FILES ${DUCKDB_LIB_FILE}
    DESTINATION lib
    COMPONENT Runtime)

# Find CCACHE (Speedup recompilation)
find_program(CCACHE_FOUND ccache)
if(CCACHE_FOUND)
    set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE ccache)
endif(CCACHE_FOUND)
