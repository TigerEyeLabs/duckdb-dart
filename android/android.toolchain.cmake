# android.toolchain.cmake

# Set Android specific variables
set(CMAKE_SYSTEM_NAME Android)
set(CMAKE_SYSTEM_VERSION 23)  # Minimum supported API level
set(CMAKE_ANDROID_STL_TYPE c++_static)
set(CMAKE_ANDROID_NDK_TOOLCHAIN_VERSION clang)
set(CMAKE_ANDROID_ARCH_ABI ${ANDROID_ABI})

# Enable flexible page sizes for Android API 35+
set(ANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES ON)

# Include the Android NDK toolchain
include("$ENV{ANDROID_NDK_HOME}/build/cmake/android.toolchain.cmake")

# Include vcpkg toolchain after Android toolchain
include("$ENV{VCPKG_TOOLCHAIN_PATH}")

# Additional settings for cross-compilation
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# Force static linking for Android
set(BUILD_SHARED_LIBS OFF CACHE BOOL "Build shared libraries" FORCE)

# Set linker options for all targets
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,-z,max-page-size=16384")
set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,-z,max-page-size=16384")
