VERSION = v1.4.2
DUCKDB_REPO = https://github.com/duckdb/duckdb
DUCKDB_DIR = ./duckdb

# common environment variables
export BUILD_SHELL=0

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

release: duckdb ## x64 linux build
	@export DUCKDB_PLATFORM=linux_amd64; \
	export DUCKDB_EXTENSIONS='icu;parquet;json;fts;autocomplete'; \
	make -C $(DUCKDB_DIR) GEN=ninja release; \
	mv $(DUCKDB_DIR)/build/release/src/libduckdb.so ./Libraries/release/libduckdb.so;

help: ## Display this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
