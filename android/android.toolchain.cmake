set(CMAKE_SYSTEM_NAME Android)
set(CMAKE_SYSTEM_VERSION $ENV{ANDROID_NATIVE_API_LEVEL}) # Set this to your target Android API level
set(CMAKE_ANDROID_ARCH_ABI $ENV{ANDROID_ABI}) # Set this to your target Android ABI (armeabi-v7a, arm64-v8a, x86, x86_64, etc.)

set(CMAKE_ANDROID_NDK $ENV{ANDROID_NDK_HOME})
set(CMAKE_ANDROID_STL_TYPE c++_static)

set(CMAKE_ANDROID_NDK_TOOLCHAIN_VERSION clang)
set(CMAKE_ANDROID_NDK_TOOLCHAIN_HOST_TAG linux-x86_64) # Replace with your platform if necessary
set(CMAKE_ANDROID_TOOLCHAIN clang)
set(CMAKE_ANDROID_ALLOW_UNDEFINED_SYMBOLS TRUE)
