VERSION = v1.1.3
DUCKDB_REPO = https://github.com/duckdb/duckdb
DUCKDB_DIR = ./duckdb
IOS_PLATFORM_SIMULATOR = iPhoneSimulator
IOS_PLATFORM_DEVICE = iPhoneOS

# common environment variables
export CMAKE_TOOLCHAIN_FILE=$(PWD)/ios.toolchain.cmake
export BUILD_SHELL=0

.PHONY: all reset clean sim device help

all: reset device ## Full Device Build

reset: ## Reset build environment
	rm -rf ./Libraries/*
	mkdir -p ./Libraries/release
	rm -rf $(DUCKDB_DIR)

clean: ## Clean duckdb build
	make -C $(DUCKDB_DIR) clean;

duckdb: ## Clone DuckDb repo and apply patch
	git clone --depth 1 --branch "$(VERSION)" $(DUCKDB_REPO) $(DUCKDB_DIR)
	git -C $(DUCKDB_DIR) apply ../changes.patch

sim_x64: duckdb ## Simulator build for ARM64
	@export OSX_BUILD_ARCH='x86_64'; \
	export IOS_PLATFORM=$(IOS_PLATFORM_SIMULATOR) \
	export DUCKDB_PLATFORM=osx_amd64; \
	export DUCKDB_EXTENSIONS='icu;parquet;json;fts;autocomplete'; \
	make -C $(DUCKDB_DIR) GEN=ninja release; \
	cp $(DUCKDB_DIR)/src/include/duckdb.h $(DUCKDB_DIR)/build/release/src/duckdb.framework/Headers
	mv $(DUCKDB_DIR)/build/release/src/duckdb.framework ./Libraries/release/duckdb_x64.framework

sim_arm64: duckdb ## Simulator build for ARM64
	@export OSX_BUILD_ARCH='arm64'; \
	export IOS_PLATFORM=$(IOS_PLATFORM_SIMULATOR) \
	export DUCKDB_PLATFORM=osx_arm64; \
	export DUCKDB_EXTENSIONS='icu;parquet;json;fts;autocomplete'; \
	make -C $(DUCKDB_DIR) GEN=ninja release; \
	cp $(DUCKDB_DIR)/src/include/duckdb.h $(DUCKDB_DIR)/build/release/src/duckdb.framework/Headers
	mv $(DUCKDB_DIR)/build/release/src/duckdb.framework ./Libraries/release/duckdb_arm64.framework

simulator: sim_arm64 clean sim_x64 ## Univerasl iOS Simulator Build
	mv ./Libraries/release/duckdb_arm64.framework ./Libraries/release/duckdb.framework
	lipo -create ./Libraries/release/duckdb.framework/duckdb ./Libraries/release/duckdb_x64.framework/duckdb -output ./Libraries/release/duckdb.framework/duckdb
	rm -rf ./Libraries/release/duckdb_x64.framework
	@echo "Universal Simulator Build Complete"

device: duckdb ## iOS Hardware Build
device:
	@export IOS_PLATFORM=$(IOS_PLATFORM_DEVICE) \
	export DUCKDB_EXTENSIONS='icu;parquet;json;fts;autocomplete'; \
	export DUCKDB_PLATFORM=osx_arm64; \
	make -C $(DUCKDB_DIR) GEN=ninja release; \
	cp $(DUCKDB_DIR)/src/include/duckdb.h $(DUCKDB_DIR)/build/release/src/duckdb.framework/Headers
	mv $(DUCKDB_DIR)/build/release/src/duckdb.framework ./Libraries/release
	echo "Release build complete"

help: ## Display this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
