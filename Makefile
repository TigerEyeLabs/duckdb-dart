# Code Coverage Thresholds
LINE_COVERAGE_THRESHOLD := 0
BRANCH_COVERAGE_THRESHOLD := 0

CHECK_GIT ?= 0

FLUTTER_VERSION := 3.29.2

RUN_CHROME_TESTS ?= 0

# Detect the operating system using uname
OS := $(shell uname 2>/dev/null || echo Windows)

ifeq ($(OS),Darwin)
	BUILD_OS := macos
else ifeq ($(OS),Linux)
	BUILD_OS := linux
else
	BUILD_OS := windows
endif

ifeq ($(BUILD_OS), windows)
	GENHTML := $(shell powershell -Command "(Get-Command genhtml).Source")
	PERL := $(shell powershell -Command "(Get-Command perl).Source")
else
	GENHTML := $(shell which genhtml)
	PERL := $(shell which perl)
endif

.PHONY: setup
setup:
	fvm install ${FLUTTER_VERSION}
	fvm use -f ${FLUTTER_VERSION}

clean: setup ## Remove build artifacts
	fvm flutter clean
ifeq ($(BUILD_OS),windows)
	powershell -Command "if (Test-Path coverage) { Remove-Item -Recurse -Force coverage }"
else
	rm -rf coverage
endif

build: setup ## Build the package
	fvm flutter pub get
	fvm dart run ffigen --config ffi_native.yaml
	@if [ $(CHECK_GIT) -eq 1 ] && [ -n "$$(git status --porcelain | grep -v '^\?\? ' | grep -v '^A  ')" ]; then \
		{ echo "Uncommitted changes detected. Failing the build."; \
		git status --porcelain | grep -v '^\?\? ' | grep -v '^A  ' | cut -c 4-; \
		git diff; \
		} > /dev/stdout; \
		exit 1; \
	fi

.PHONY: test
test: build ## Run base unit tests
	mkdir -p coverage/vm
	# Run VM tests
	fvm dart test --platform vm --coverage=./coverage/vm --reporter json > coverage/report-duckdb.dart.jsonl
ifeq ($(RUN_CHROME_TESTS),1)
	mkdir -p coverage/chrome
	# Run Chrome tests with additional flags
	fvm dart test --platform chrome --coverage=./coverage/chrome
	# Merge and format coverage for both VM and Chrome
	fvm dart run coverage:format_coverage \
		-i ./coverage/vm \
		-i ./coverage/chrome \
		-o ./coverage/duckdb.dart.lcov \
		--lcov \
		--report-on lib/
else
	# Format coverage for VM only
	fvm dart run coverage:format_coverage \
		-i ./coverage/vm \
		-o ./coverage/duckdb.dart.lcov \
		--lcov \
		--report-on lib/
endif
	lcov --remove coverage/duckdb.dart.lcov '*.g.dart' -o coverage/duckdb.dart.lcov
	lcov --rc lcov_branch_coverage=1 --summary coverage/duckdb.dart.lcov > coverage/duckdb.dart-summary.info
ifeq ($(BUILD_OS), windows)
	@powershell -Command "$(PERL) $(GENHTML) --branch-coverage coverage/duckdb.dart.lcov -o coverage/html"
else
	genhtml coverage/duckdb.dart.lcov --branch-coverage -o coverage/html
endif

.PHONY: explorer
explorer: ## Build and run duckdbexplorer
	cd examples/duckdbexplorer && fvm flutter run -d $(BUILD_OS)

analyze: setup ## Run flutter analyze
	fvm flutter analyze --fatal-infos --fatal-warnings --write analyze.txt

fix: ## Run dart fix
	fvm dart fix --apply

format: ## Run dart format
	fvm dart format .

.PHONY: macos
macos: ## Build for MacOS
	cd macos && make all

.PHONY: ios_sim
ios_sim: ## Build for iOS Simulator
	cd ios && make simulator

.PHONY: ios_device
ios_device: ## Build for iOS Device
	cd ios && make device

.PHONY: linux
linux: ## Build for Linux
	cd linux && make all

.PHONY: android
android: ## Build for Android
	cd android && make all

## CI tasks
quality: setup ## Run codequality for CI
	find . -name "*.dart" ! -name "*.g.dart" ! -path '*/.dart_tool/*' | tr '\n' ' ' | xargs fvm dart format --set-exit-if-changed --output=none

.PHONY: help
help:
	# TigerEye duckdb.dart Package
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
