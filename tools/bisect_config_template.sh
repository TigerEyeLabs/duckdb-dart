#!/bin/bash

# DuckDB Bisect Test Configuration Template
# Copy this file and modify the values for your specific test case

# =============================================================================
# CONFIGURATION EXAMPLES - UNCOMMENT AND MODIFY AS NEEDED
# =============================================================================

# Example 1: Testing for "Not implemented Error"
# DB_PATH="/Users/aprock/Library/Containers/com.tigereye.app/Data/Documents/verkada/db.timedb"
# SQL_FILE="bad.sql"
# DUCKDB_BINARY="./build/release/duckdb"
# TEST_DESCRIPTION="Not implemented Error"
# ERROR_PATTERN="not implemented"
# TIMEOUT_SECONDS=60
# BUILD_COMMAND="GEN=ninja make release BUILD_ICU=1"
# CLEAN_COMMAND="make clean"

# Example 2: Testing for memory errors
# DB_PATH=""  # Empty for in-memory database
# SQL_FILE="memory_test.sql"
# DUCKDB_BINARY="./build/debug/duckdb"
# TEST_DESCRIPTION="Memory error"
# ERROR_PATTERN="memory|segmentation fault|malloc"
# TIMEOUT_SECONDS=30
# BUILD_COMMAND="GEN=ninja make debug"
# CLEAN_COMMAND="make clean"

# Example 3: Testing for specific exception
# DB_PATH="test.db"
# SQL_FILE="crash_test.sql"
# DUCKDB_BINARY="./build/release/duckdb"
# TEST_DESCRIPTION="Specific exception"
# ERROR_PATTERN="runtime error|exception"
# TIMEOUT_SECONDS=120
# BUILD_COMMAND="make release"
# CLEAN_COMMAND="make clean"

# Example 4: Testing with custom build flags
# DB_PATH=":memory:"
# SQL_FILE="feature_test.sql"
# DUCKDB_BINARY="./build/release/duckdb"
# TEST_DESCRIPTION="Feature not working"
# ERROR_PATTERN="unsupported|not supported"
# TIMEOUT_SECONDS=60
# BUILD_COMMAND="GEN=ninja make release BUILD_PYTHON=1 BUILD_R=1"
# CLEAN_COMMAND="make clean"
# SETUP_COMMANDS="export PYTHONPATH=/path/to/python; source activate_env.sh"

# =============================================================================
# QUICK SETUP GUIDE
# =============================================================================
# 1. Copy this file: cp bisect_config_template.sh my_test_config.sh
# 2. Uncomment and modify one of the examples above
# 3. Create your SQL test file
# 4. Run: source my_test_config.sh && ./bisect_test_template.sh
#
# OR integrate directly into the template:
# 1. Copy the template: cp bisect_test_template.sh my_bisect_test.sh
# 2. Edit the configuration section in my_bisect_test.sh
# 3. Run: ./my_bisect_test.sh

# =============================================================================
# COMMON PATTERNS TO SEARCH FOR
# =============================================================================
# Error patterns (case-insensitive):
# - "not implemented" - for unimplemented features
# - "memory|segmentation fault|malloc" - for memory issues
# - "runtime error|exception" - for general exceptions
# - "assertion failed|assert" - for assertion failures
# - "internal error" - for internal DuckDB errors
# - "timeout|killed" - for timeout/hanging issues
# - "syntax error" - for parsing issues
# - "bind|binding" - for binding errors
# - "optimizer" - for optimization issues
# - "execution" - for execution errors

# =============================================================================
# COMMON BUILD COMMANDS
# =============================================================================
# Release build: "GEN=ninja make release"
# Debug build: "GEN=ninja make debug"
# With ICU: "GEN=ninja make release BUILD_ICU=1"
# With Python: "GEN=ninja make release BUILD_PYTHON=1"
# With extensions: "GEN=ninja make release BUILD_EXTENSIONS='json;parquet'"
# Sanitizer build: "GEN=ninja make debug BUILD_SANITIZER=1"

# =============================================================================
# BISECT USAGE
# =============================================================================
# 1. Start bisect: git bisect start
# 2. Mark bad commit: git bisect bad [commit_hash]
# 3. Mark good commit: git bisect good [commit_hash]
# 4. Run bisect: git bisect run ./my_bisect_test.sh
# 5. When done: git bisect reset
