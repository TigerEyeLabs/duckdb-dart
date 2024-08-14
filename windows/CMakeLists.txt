# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "dart_duckdb")
project(${PROJECT_NAME} LANGUAGES CXX)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "dart_duckdb_plugin")

# Any new source files that you add to the plugin should be added here.
list(APPEND PLUGIN_SOURCES
  "dart_duckdb_plugin.cpp"
  "dart_duckdb_plugin.h"
)

# Essentially, the idea of this build script is to compile a duckdb.dll
# and make Flutter bundle that with the final app.

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
add_library(${PLUGIN_NAME} SHARED
  "include/dart_duckdb/dart_duckdb_plugin_c_api.h"
  "dart_duckdb_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

# Apply a standard set of build settings that are configured in the
# application-level CMakeLists.txt. This can be removed for plugins that want
# full control over build settings.
apply_standard_settings(${PLUGIN_NAME})

# Symbols are hidden by default to reduce the chance of accidental conflicts
# between plugins. This should not be removed; any symbols that should be
# exported should be explicitly exported with the FLUTTER_PLUGIN_EXPORT macro.
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# Source include directories and library dependencies. Add any plugin-specific
# dependencies here.
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

# Paths to the prebuilt DuckDB DLLs
# set(PREBUILT_DEBUG_DUCKDB_DLL "${CMAKE_CURRENT_SOURCE_DIR}/Libraries/debug/duckdb.dll")
set(PREBUILT_RELEASE_DUCKDB_DLL "${CMAKE_CURRENT_SOURCE_DIR}/Libraries/release/duckdb.dll")

# Add DuckDB library
# if(CMAKE_BUILD_TYPE MATCHES Debug)
#   file(GLOB DUCKDB_DLL "${PREBUILT_DEBUG_DUCKDB_DLL}")
# else()
file(GLOB DUCKDB_DLL "${PREBUILT_RELEASE_DUCKDB_DLL}")
# endif()

# Add DuckDB library
add_library(duckdb SHARED IMPORTED)
set_property(TARGET duckdb PROPERTY IMPORTED_LOCATION "${DUCKDB_DLL}")

# Ensure duckdb actually gets built
add_dependencies(${PLUGIN_NAME} duckdb)

# Copy the duckdb.dll to the build output directory based on the build type
get_filename_component(RELEASE_OUTPUT_DIR "${CMAKE_BINARY_DIR}/../../build/windows/runner/Release/" ABSOLUTE)
get_filename_component(DEBUG_OUTPUT_DIR "${CMAKE_BINARY_DIR}/../../build/windows/runner/Debug/" ABSOLUTE)
file(COPY ${DUCKDB_DLL} DESTINATION ${RELEASE_OUTPUT_DIR})
file(COPY ${DUCKDB_DLL} DESTINATION ${DEBUG_OUTPUT_DIR})

# List of absolute paths to libraries that should be bundled with the plugin.
set(dart_duckdb_bundled_libraries
  "$<$<CONFIG:Debug>:${DEBUG_OUTPUT_DIR}/duckdb.dll>"
  "$<$<CONFIG:Release>:${RELEASE_OUTPUT_DIR}/duckdb.dll>"
  PARENT_SCOPE
)
