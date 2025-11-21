VERSION = v1.4.2
DUCKDB_REPO = https://github.com/duckdb/duckdb
DUCKDB_DIR = ./duckdb
IOS_PLATFORM_SIMULATOR = iPhoneSimulator
IOS_PLATFORM_DEVICE = iPhoneOS

# common environment variables
export CMAKE_TOOLCHAIN_FILE=$(PWD)/ios.toolchain.cmake
export BUILD_SHELL=0
export CCACHE_DIR=$(PWD)/.ccache
export BUILD_TESTING=OFF
export BUILD_UNITTESTS=OFF

.PHONY: all reset clean sim device destination help

all: reset device ## Full Device Build

reset: ## Reset build environment
	rm -rf ./Libraries/*
	rm -rf $(DUCKDB_DIR)

clean: ## Clean duckdb build
	make -C $(DUCKDB_DIR) clean;

duckdb: ## Clone DuckDb repo and apply patch
	git clone --depth 1 --branch "$(VERSION)" $(DUCKDB_REPO) $(DUCKDB_DIR)
	git -C $(DUCKDB_DIR) apply ../changes.patch

destination:
	mkdir -p ./Libraries/release $(CCACHE_DIR)

sim_x64: destination duckdb ## Simulator build for ARM64
	@export OSX_BUILD_ARCH='x86_64'; \
	export IOS_PLATFORM=$(IOS_PLATFORM_SIMULATOR) \
	export DUCKDB_PLATFORM=osx_amd64; \
	export DUCKDB_EXTENSIONS='icu;parquet;json;autocomplete'; \
	make -C $(DUCKDB_DIR) GEN=ninja release; \
	cp $(DUCKDB_DIR)/src/include/duckdb.h $(DUCKDB_DIR)/build/release/src/duckdb.framework/Headers
	mv $(DUCKDB_DIR)/build/release/src/duckdb.framework ./Libraries/release/duckdb_x64.framework

sim_arm64: destination duckdb ## Simulator build for ARM64
	@export OSX_BUILD_ARCH='arm64'; \
	export IOS_PLATFORM=$(IOS_PLATFORM_SIMULATOR) \
	export DUCKDB_PLATFORM=osx_arm64; \
	export DUCKDB_EXTENSIONS='icu;parquet;json;autocomplete'; \
	make -C $(DUCKDB_DIR) GEN=ninja release; \
	cp $(DUCKDB_DIR)/src/include/duckdb.h $(DUCKDB_DIR)/build/release/src/duckdb.framework/Headers
	mv $(DUCKDB_DIR)/build/release/src/duckdb.framework ./Libraries/release/duckdb_arm64.framework

simulator: destination sim_arm64 clean sim_x64 ## Univerasl iOS Simulator Build
	mv ./Libraries/release/duckdb_arm64.framework ./Libraries/release/duckdb.framework
	lipo -create ./Libraries/release/duckdb.framework/duckdb ./Libraries/release/duckdb_x64.framework/duckdb -output ./Libraries/release/duckdb.framework/duckdb
	rm -rf ./Libraries/release/duckdb_x64.framework
	@echo "Universal Simulator Build Complete"

device: destination duckdb ## iOS Hardware Build
device:
	@export IOS_PLATFORM=$(IOS_PLATFORM_DEVICE) \
	export DUCKDB_EXTENSIONS='icu;parquet;json;autocomplete'; \
	export DUCKDB_PLATFORM=osx_arm64; \
	make -C $(DUCKDB_DIR) GEN=ninja release; \
	cp $(DUCKDB_DIR)/src/include/duckdb.h $(DUCKDB_DIR)/build/release/src/duckdb.framework/Headers
	mv $(DUCKDB_DIR)/build/release/src/duckdb.framework ./Libraries/release
	echo "Release build complete"

help: ## Display this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
