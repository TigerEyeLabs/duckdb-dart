# Code Coverage Thresholds
LINE_COVERAGE_THRESHOLD := 0
BRANCH_COVERAGE_THRESHOLD := 0

CHECK_GIT ?= 0
PLATFORM ?=

FLUTTER_VERSION := 3.35.3

# Detect the operating system
ifeq ($(OS),Windows_NT)
	BUILD_OS := windows
	MKDIR_CMD := powershell -Command "New-Item -ItemType Directory -Force -Path"
	RM_CMD := powershell -Command "Remove-Item -Recurse -Force -ErrorAction SilentlyContinue"
	TEST_PATH_CMD := powershell -Command "Test-Path"
	GET_CMD := powershell -Command "Get-Command"
	WRITE_HOST := powershell -Command "Write-Host"
	WHERE_OBJECT := powershell -Command "Where-Object"
	FOR_EACH_OBJECT := powershell -Command "ForEach-Object"
	SELECT_OBJECT := powershell -Command "Select-Object"
	SUBSTRING := powershell -Command "Substring"
	LCOV_PATH := $(shell powershell -Command "if (Test-Path 'C:\ProgramData\chocolatey\lib\lcov\tools\bin\lcov') { Write-Output 'C:\ProgramData\chocolatey\lib\lcov\tools\bin\lcov' } else { Write-Output 'lcov' }")
	GENHTML_PATH := $(shell powershell -Command "if (Test-Path 'C:\ProgramData\chocolatey\lib\lcov\tools\bin\genhtml') { Write-Output 'C:\ProgramData\chocolatey\lib\lcov\tools\bin\genhtml' } else { Write-Output 'genhtml' }")
else
	BUILD_OS := $(shell uname)
	# Unix commands
	MKDIR_CMD := mkdir -p
	RM_CMD := rm -rf
	LCOV_PATH := lcov
	GENHTML_PATH := genhtml
endif

ifeq ($(BUILD_OS),Darwin)
	BUILD_OS := macos
else ifeq ($(BUILD_OS),Linux)
	BUILD_OS := linux
endif

.PHONY: setup
setup: ## Setup development environment
	fvm install ${FLUTTER_VERSION} --skip-pub-get
	fvm use ${FLUTTER_VERSION} --skip-setup

.PHONY: ffigen
ffigen: setup ## Generate FFI bindings
ifeq ($(BUILD_OS),windows)
	@powershell -NoProfile -Command "if (-not (Test-Path 'lib/src/ffi/duckdb.g.dart')) { fvm flutter pub global activate ffigen; fvm dart run ffigen --config ffi_native.yaml }"
else
	@if [ ! -f "lib/src/ffi/duckdb.g.dart" ]; then \
		fvm flutter pub global activate ffigen; \
		fvm dart run ffigen --config ffi_native.yaml; \
	fi
endif

clean: setup ## Remove build artifacts
	fvm flutter clean
	$(RM_CMD) coverage
	$(RM_CMD) lib/src/ffi/duckdb.g.dart

build: setup ffigen ## Build the package
	fvm flutter pub get --offline || fvm flutter pub get
ifneq ($(BUILD_OS),windows)
	@if [ $(CHECK_GIT) -eq 1 ] && [ -n "$$(git status --porcelain | grep -v '^\?\? ' | grep -v '^A  ')" ]; then \
		{ echo "Uncommitted changes detected. Failing the build."; \
		git status --porcelain | grep -v '^\?\? ' | grep -v '^A  ' | cut -c 4-; \
		git diff; \
		} > /dev/stdout; \
		exit 1; \
	fi
endif

.PHONY: test
test: build ## Run VM tests without coverage
	@echo "=== Starting test execution ==="
ifneq ($(PLATFORM),)
	fvm dart test --platform $(PLATFORM)
else
	fvm dart test
endif

.PHONY: test-coverage
test-coverage: build ## Run VM tests with coverage report
	@echo "=== Starting test execution with coverage ==="
	@echo "Creating coverage directory..."
	$(MKDIR_CMD) coverage/vm
	@echo "Running VM tests..."
ifneq ($(PLATFORM),)
	fvm dart test --coverage=./coverage/vm --reporter json --platform $(PLATFORM) > coverage/report-duckdb.dart.jsonl
else
	fvm dart test --coverage=./coverage/vm --reporter json > coverage/report-duckdb.dart.jsonl
endif
	@echo "Formatting coverage data..."
	fvm dart run coverage:format_coverage \
		-i ./coverage/vm \
		-o ./coverage/duckdb.dart.lcov \
		--lcov \
		--report-on lib/
	@echo "Processing coverage data..."
ifneq ($(BUILD_OS),windows)
	@echo "Unix: Removing generated files from coverage..."
	$(LCOV_PATH) --remove coverage/duckdb.dart.lcov '*.g.dart' -o coverage/duckdb.dart.lcov
	@echo "Unix: Generating coverage summary..."
	$(LCOV_PATH) --rc lcov_branch_coverage=1 --summary coverage/duckdb.dart.lcov > coverage/duckdb.dart-summary.info
	$(GENHTML_PATH) coverage/duckdb.dart.lcov --branch-coverage -o coverage/html
	@echo "=== Test execution completed ==="
	@echo "Coverage report available in coverage/html/index.html"
endif

.PHONY: explorer
explorer: ## Build and run duckdbexplorer
	cd examples/duckdbexplorer && fvm flutter run -d $(BUILD_OS)

explorer-web: ## Build and run duckdbexplorer
	cd examples/duckdbexplorer && fvm flutter run -d chrome --web-browser-flag "--disable-web-security"

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
	fvm dart pub get
	find . -name "*.dart" ! -name "*.g.dart" ! -path '*/.dart_tool/*' | tr '\n' ' ' | xargs fvm dart format --set-exit-if-changed --output=none

.PHONY: help
help:
	# TigerEye duckdb.dart Package
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
