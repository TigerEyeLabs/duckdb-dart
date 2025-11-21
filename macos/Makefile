VERSION = v1.4.2
DUCKDB_REPO = https://github.com/duckdb/duckdb
DUCKDB_DIR = ./duckdb

# common environment variables
export BUILD_SHELL=0
export OSX_BUILD_UNIVERSAL=1

.PHONY: all reset clean release help

all: reset release ## Full Build

reset: ## Reset build environment
	rm -rf ./Libraries/*
	mkdir -p ./Libraries/release
	rm -rf $(DUCKDB_DIR)

## Clean duckdb build
clean:
	make -C $(DUCKDB_DIR) clean;

duckdb: ## Clone DuckDb repo and apply patch
	git clone --depth 1 --branch "$(VERSION)" $(DUCKDB_REPO) $(DUCKDB_DIR)

release_x64: duckdb ## x64 osx build
	@export OSX_BUILD_ARCH='x86_64'; \
	export DUCKDB_PLATFORM=osx_amd64; \
	export DUCKDB_EXTENSIONS='icu;parquet;json;fts;autocomplete'; \
	make -C $(DUCKDB_DIR) GEN=ninja release; \
	mv $(DUCKDB_DIR)/build/release/src/libduckdb.dylib ./Libraries/release/libduckdb_x64.dylib;

release_arm64: duckdb ## arm64 osx build
	@export OSX_BUILD_ARCH='arm64'; \
	export DUCKDB_PLATFORM=osx_arm64; \
	export DUCKDB_EXTENSIONS='icu;parquet;json;fts;autocomplete'; \
	make -C $(DUCKDB_DIR) GEN=ninja release; \
	mv $(DUCKDB_DIR)/build/release/src/libduckdb.dylib ./Libraries/release/libduckdb_arm64.dylib;

release: release_arm64 clean release_x64 ## Universal osx release build
	lipo -create ./Libraries/release/libduckdb_arm64.dylib ./Libraries/release/libduckdb_x64.dylib -output ./Libraries/release/libduckdb.dylib
	rm -rf ./Libraries/release/libduckdb_arm64.dylib ./Libraries/release/libduckdb_x64.dylib
	echo "Universal Release Build Complete"

help: ## Display this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
