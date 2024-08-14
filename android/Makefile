# Android Build Makefile for DuckDB

# Version configuration
VERSION = v1.0.0
DUCKDB_DIR = ./duckdb

# Environment variables
export ANDROID_TOOLCHAIN_PATH=$(PWD)/android.toolchain.cmake
export ANDROID_NATIVE_API_LEVEL=21
export DUCKDB_PLATFORM=linux_arm64
export BUILD_SHELL=0

# ABIs to build for
ABIS := armeabi-v7a arm64-v8a x86 x86_64

# Phony targets
.PHONY: all reset clean build

all: reset build ## Full Build

reset: ## Reset build environment
	rm -rf src/main/jniLibs/*
	rm -rf $(DUCKDB_DIR)

duckdb: ## Clone the DuckDB repository
	git clone --depth 1 --branch "$(VERSION)" https://github.com/duckdb/duckdb $(DUCKDB_DIR)
	git -C $(DUCKDB_DIR) apply ../changes.patch

build: duckdb ## Build for each ABI
	@$(foreach abi,$(ABIS),\
		export DUCKDB_EXTENSIONS='icu;parquet;json;fts;autocomplete'; \
		export ANDROID_ABI=$(abi); \
		echo "Building $(abi) $(PWD)"; \
		mkdir -p ./src/main/jniLibs/$(abi); \
		make -C $(DUCKDB_DIR) GEN=ninja release; \
		cp $(DUCKDB_DIR)/build/release/src/libduckdb.so ./src/main/jniLibs/$(abi)/libduckdb.so; \
		make -C $(DUCKDB_DIR) clean; \
		echo "Build for $(abi) complete";)

help: ## Display this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
