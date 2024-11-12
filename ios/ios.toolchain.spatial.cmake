# ios.toolchain.cmake

set(CMAKE_SYSTEM_NAME iOS)

# Set the default iOS platform (adjust to your needs)
set(IOS_PLATFORM $ENV{IOS_PLATFORM} CACHE STRING "iOS platform: iPhoneOS or iPhoneSimulator")
set(DUCKDB_PLATFORM $ENV{DUCKDB_PLATFORM})
set(SUPPORTED_PLATFORMS "MacOS")
set(VCPKG_TOOLCHAIN_PATH $ENV{VCPKG_TOOLCHAIN_PATH})

# Determine the correct SDK and architecture based on the platform
if(IOS_PLATFORM STREQUAL "iPhoneSimulator")
    set(CMAKE_OSX_SYSROOT "iphonesimulator")
elseif(IOS_PLATFORM STREQUAL "iPhoneOS")
    set(CMAKE_OSX_SYSROOT "iphoneos")
else()
    message(FATAL_ERROR "Invalid iOS platform: ${IOS_PLATFORM}")
endif()

if(DUCKDB_PLATFORM STREQUAL "osx_amd64")
    set(CMAKE_OSX_ARCHITECTURES "x86_64" CACHE STRING "Build architectures for iOS" FORCE)
elseif(DUCKDB_PLATFORM STREQUAL "osx_arm64")
    set(CMAKE_OSX_ARCHITECTURES "arm64" CACHE STRING "Build architectures for iOS" FORCE)
else()
    message(FATAL_ERROR "Invalid duckdb platform: ${DUCKDB_PLATFORM}")
endif()

# Specify the minimum deployment target
set(CMAKE_OSX_DEPLOYMENT_TARGET "11.0")

# Set the C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Force Xcode to use the correct SDK
set(CMAKE_XCODE_EFFECTIVE_PLATFORMS "-iphoneos;-iphonesimulator")

include(${VCPKG_TOOLCHAIN_PATH})
