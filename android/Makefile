# Variables
VERSION = v1.4.2
DUCKDB_REPO = https://github.com/duckdb/duckdb
DUCKDB_DIR = duckdb
BUILD_DIR = $(DUCKDB_DIR)/build
LIB_DIR = src/main/jniLibs/
EXTENSIONS = 'icu;parquet;json;autocomplete'

ifndef ANDROID_NDK_HOME
# https://developer.android.com/studio
$(error ANDROID_NDK_HOME is not set)
endif

# Detect the host system
HOST_OS := $(shell uname -s | tr A-Z a-z)
ifeq ($(HOST_OS),darwin)
    HOST_PLATFORM := darwin-x86_64
else
    HOST_PLATFORM := linux-x86_64
endif

# Check if Ninja is available
NINJA := $(shell which ninja)
CMAKE_GENERATOR := $(if $(NINJA),-G Ninja,)

# Add these new variables
ENABLE_EXTENSION_AUTOLOADING = 1
ENABLE_EXTENSION_AUTOINSTALL = 1
EXTENSION_STATIC_BUILD = 1
CMAKE_VARS_BUILD = -DBUILD_UNITTESTS=0 \
    -DBUILD_SHELL=0 \
    -DCMAKE_TOOLCHAIN_FILE='${ANDROID_NDK_HOME}/build/cmake/android.toolchain.cmake' \
    -DANDROID_PLATFORM=android-21 \
    -DANDROID_STL=c++_static \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DBUILD_SHARED_LIBS=OFF

.PHONY: all reset release help

all: reset release ## Full Build

reset: ## Reset build environment
	rm -rf $(LIB_DIR) $(DUCKDB_DIR)

## Clean duckdb build
clean:
	make -C $(DUCKDB_DIR) clean

duckdb: ## Shallow clone DuckDb repo and checkout specific commit
	git clone --depth 1 --branch "$(VERSION)" $(DUCKDB_REPO) $(DUCKDB_DIR)

build_%: duckdb
	@mkdir -p $(BUILD_DIR)/extension_configuration
	@cd $(BUILD_DIR)/extension_configuration && \
		ANDROID_ABI=$* \
		cmake $(CMAKE_GENERATOR) \
		-DEXTENSION_CONFIG_BUILD=TRUE \
		-DCMAKE_BUILD_TYPE=MinSizeRel \
		-DANDROID_ABI=$* \
		../.. && \
		cmake --build . --config MinSizeRel
	@mkdir -p $(BUILD_DIR)
	@cd $(BUILD_DIR) && \
		ANDROID_ABI=$* \
		cmake $(CMAKE_GENERATOR) \
		-DANDROID_ABI=$* \
		-DDUCKDB_EXPLICIT_PLATFORM='android_$*' \
		-DCMAKE_BUILD_TYPE=Release \
		-DBUILD_EXTENSIONS=$(EXTENSIONS) \
		-DENABLE_EXTENSION_AUTOLOADING=$(ENABLE_EXTENSION_AUTOLOADING) \
		-DENABLE_EXTENSION_AUTOINSTALL=$(ENABLE_EXTENSION_AUTOINSTALL) \
		-DEXTENSION_STATIC_BUILD=$(EXTENSION_STATIC_BUILD) \
		$(CMAKE_VARS_BUILD) \
		../ && \
		cmake --build . --config Release --parallel
	@${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/$(HOST_PLATFORM)/bin/llvm-strip --strip-debug $(BUILD_DIR)/src/libduckdb.so
	@mkdir -p $(LIB_DIR)/$*
	@cp $(BUILD_DIR)/src/libduckdb.so $(LIB_DIR)/$*/libduckdb.so;

release: build_arm64-v8a clean build_armeabi-v7a ## Build for each ABI
	echo "Android Release Build Complete"

help: ## Display this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
