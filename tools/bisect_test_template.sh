#!/bin/bash

# DuckDB Bisect Test Template
# This script tests if a commit introduces a specific error or behavior
# Exit code 0 = good commit (no error)
# Exit code 1 = bad commit (has the error/issue)
# Exit code 125 = skip commit (build failed or other issue)

set -e

# =============================================================================
# CONFIGURATION - MODIFY THESE VALUES FOR YOUR SPECIFIC TEST
# =============================================================================

# Database configuration
DB_PATH="/path/to/your/database.db"
SQL_FILE="test_query.sql"
DUCKDB_BINARY="./build/release/duckdb"

# Test configuration
TEST_DESCRIPTION="Not implemented Error"           # Description of what we're testing for
ERROR_PATTERN="not implemented"                   # Pattern to search for in output (case-insensitive)
TIMEOUT_SECONDS=60                                 # Timeout for SQL execution

# Build configuration
BUILD_COMMAND="GEN=ninja make release BUILD_ICU=1"  # Build command to use
CLEAN_COMMAND="make clean"                          # Clean command to use

# Optional: Additional setup commands (leave empty if not needed)
SETUP_COMMANDS=""
# Example: SETUP_COMMANDS="export SOME_VAR=value; source setup.sh"

# =============================================================================
# MAIN SCRIPT - GENERALLY NO NEED TO MODIFY BELOW THIS LINE
# =============================================================================

echo "=== DuckDB Bisect Test Script ==="
echo "Testing for: $TEST_DESCRIPTION"
echo "Testing commit: $(git rev-parse HEAD)"
echo "Timestamp: $(date)"
echo ""

# Step 1: Run any setup commands
if [ -n "$SETUP_COMMANDS" ]; then
    echo "Running setup commands..."
    eval "$SETUP_COMMANDS"
fi

# Step 2: Clean previous build
echo "Cleaning previous build..."
if ! $CLEAN_COMMAND; then
    echo "WARNING: Clean command failed, continuing anyway..."
fi

# Step 3: Build DuckDB
echo "Building DuckDB ($BUILD_COMMAND)..."
if ! $BUILD_COMMAND; then
    echo "ERROR: Build failed - skipping this commit"
    exit 125
fi

# Step 4: Check if binary exists
if [ ! -f "$DUCKDB_BINARY" ]; then
    echo "ERROR: DuckDB binary not found at $DUCKDB_BINARY - skipping this commit"
    exit 125
fi

# Step 5: Check if SQL file exists
if [ ! -f "$SQL_FILE" ]; then
    echo "ERROR: SQL file not found at $SQL_FILE - skipping this commit"
    exit 125
fi

# Step 6: Check if database file exists (skip if DB_PATH is empty or special value)
if [ -n "$DB_PATH" ] && [ "$DB_PATH" != ":memory:" ] && [ "$DB_PATH" != "" ]; then
    if [ ! -f "$DB_PATH" ]; then
        echo "ERROR: Database file not found at $DB_PATH - skipping this commit"
        exit 125
    fi
fi

# Step 7: Run the SQL query and capture output
echo "Running SQL query..."
OUTPUT_FILE=$(mktemp)
COMMAND_FAILED=0

# Execute the command with timeout
if [ -n "$DB_PATH" ] && [ "$DB_PATH" != "" ]; then
    # Use specified database
    timeout "$TIMEOUT_SECONDS" "$DUCKDB_BINARY" "$DB_PATH" < "$SQL_FILE" > "$OUTPUT_FILE" 2>&1 || COMMAND_FAILED=$?
else
    # Use in-memory database
    timeout "$TIMEOUT_SECONDS" "$DUCKDB_BINARY" < "$SQL_FILE" > "$OUTPUT_FILE" 2>&1 || COMMAND_FAILED=$?
fi

# Step 8: Analyze the results
if [ $COMMAND_FAILED -ne 0 ]; then
    # Command failed, check if it's due to the error we're looking for
    if grep -i "$ERROR_PATTERN" "$OUTPUT_FILE" > /dev/null; then
        echo "FOUND: $TEST_DESCRIPTION - this is a BAD commit"
        echo "Output:"
        cat "$OUTPUT_FILE"
        rm -f "$OUTPUT_FILE"
        exit 1
    else
        echo "Command failed but not due to '$TEST_DESCRIPTION' - skipping this commit"
        echo "Output:"
        cat "$OUTPUT_FILE"
        rm -f "$OUTPUT_FILE"
        exit 125
    fi
fi

# Step 9: Check output for the error pattern even if command succeeded
if grep -i "$ERROR_PATTERN" "$OUTPUT_FILE" > /dev/null; then
    echo "FOUND: $TEST_DESCRIPTION in output - this is a BAD commit"
    echo "Output:"
    cat "$OUTPUT_FILE"
    rm -f "$OUTPUT_FILE"
    exit 1
fi

# Step 10: No error found - this is a good commit
echo "SUCCESS: No '$TEST_DESCRIPTION' found - this is a GOOD commit"
echo "Output:"
cat "$OUTPUT_FILE"
rm -f "$OUTPUT_FILE"
exit 0
