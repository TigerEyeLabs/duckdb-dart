cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "dart_duckdb")
project(${PROJECT_NAME} LANGUAGES C CXX)

# Try to find the library in /usr/lib
find_library(DUCKDB_LIBRARY
             NAMES duckdb
             PATHS /usr/lib)

if(DUCKDB_LIBRARY)
  message(STATUS "Found duckdb in ${DUCKDB_LIBRARY}")
else()
  message(STATUS "Could not find duckdb")
  include(FetchContent)
  message(STATUS "Fetching DuckDB...")
  FetchContent_Declare(
    duckdb
    GIT_REPOSITORY https://github.com/duckdb/duckdb.git
    GIT_TAG v0.10.3)

  # Build these extensions into the library
  set(BUILD_EXTENSIONS ON CACHE INTERNAL "icu;parquet;json;fts;autocomplete")

  # used to test debug features
  # if(CMAKE_BUILD_TYPE STREQUAL "Debug")
  # else()
  # endif()

  # Disable ASan and UBSan globally
  add_compile_options(-fno-sanitize=address -fno-sanitize=undefined)
  add_link_options(-fno-sanitize=address -fno-sanitize=undefined)

  FetchContent_MakeAvailable(duckdb)
  message("-- Duckdb Available")
endif()

# Find CCACHE (Speedup recompilation)
find_program(CCACHE_FOUND ccache)
if(CCACHE_FOUND)
  	set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE ccache)
endif(CCACHE_FOUND)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "dart_duckdb_plugin")

add_library(${PLUGIN_NAME} SHARED
  "${CMAKE_CURRENT_SOURCE_DIR}/include/dart_duckdb/dart_duckdb_plugin.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/dart_duckdb_plugin.cc"
)

# Not applying the standard settings because we compile duckdb
# which fails with -Wall -Werror. But we apply most of them:
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
  "${duckdb_SOURCE_DIR}/src/include"
  "${duckdb_BINARY_DIR}/src/include")

if(NOT DUCKDB_LIBRARY)
  target_link_libraries(${PLUGIN_NAME} PRIVATE flutter duckdb)

  # Install the shared DuckDB library only if it is being built from source
  install(
      FILES $<TARGET_FILE:duckdb>
      DESTINATION lib
      COMPONENT Runtime)
else()
  target_link_libraries(${PLUGIN_NAME} PRIVATE flutter ${DUCKDB_LIBRARY})
endif()
