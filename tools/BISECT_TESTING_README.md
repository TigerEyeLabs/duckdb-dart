# DuckDB Bisect Testing Template

This directory contains templates for automated bisect testing of DuckDB commits to find regressions.

## Files

- `bisect_test_template.sh` - Main bisect testing script template
- `bisect_config_template.sh` - Configuration examples and reference
- `BISECT_TESTING_README.md` - This documentation

## Quick Start

### Option 1: Customize the Template Directly

1. Copy the template:
   ```bash
   cp bisect_test_template.sh my_bisect_test.sh
   ```

2. Edit the configuration section at the top of `my_bisect_test.sh`:
   ```bash
   # Modify these values for your specific test
   DB_PATH="/path/to/your/database.db"
   SQL_FILE="your_test.sql"
   ERROR_PATTERN="not implemented"
   # ... etc
   ```

3. Create your SQL test file and run:
   ```bash
   ./my_bisect_test.sh
   ```

### Option 2: Use Configuration File

1. Copy and customize the config:
   ```bash
   cp bisect_config_template.sh my_test_config.sh
   # Edit my_test_config.sh with your settings
   ```

2. Run with configuration:
   ```bash
   source my_test_config.sh && ./bisect_test_template.sh
   ```

## Configuration Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `DB_PATH` | Path to database file (empty for in-memory) | `/path/to/db.duckdb` |
| `SQL_FILE` | SQL file to execute | `test_query.sql` |
| `DUCKDB_BINARY` | Path to DuckDB binary | `./build/release/duckdb` |
| `TEST_DESCRIPTION` | Human-readable test description | `"Not implemented Error"` |
| `ERROR_PATTERN` | Pattern to search for (case-insensitive) | `"not implemented"` |
| `TIMEOUT_SECONDS` | Timeout for SQL execution | `60` |
| `BUILD_COMMAND` | Command to build DuckDB | `"GEN=ninja make release"` |
| `CLEAN_COMMAND` | Command to clean build | `"make clean"` |
| `SETUP_COMMANDS` | Optional setup commands | `"export VAR=value"` |

## Common Use Cases

### 1. Testing for "Not Implemented" Errors
```bash
DB_PATH="/path/to/database.db"
SQL_FILE="feature_test.sql"
ERROR_PATTERN="not implemented"
```

### 2. Testing for Memory Issues
```bash
DB_PATH=""  # In-memory database
SQL_FILE="memory_test.sql"
ERROR_PATTERN="memory|segmentation fault|malloc"
BUILD_COMMAND="GEN=ninja make debug BUILD_SANITIZER=1"
```

### 3. Testing for Crashes/Exceptions
```bash
DB_PATH="test.db"
SQL_FILE="crash_test.sql"
ERROR_PATTERN="runtime error|exception|assertion failed"
```

## Running Git Bisect

1. **Start bisect:**
   ```bash
   git bisect start
   ```

2. **Mark known bad commit:**
   ```bash
   git bisect bad [recent_commit_hash]
   ```

3. **Mark known good commit:**
   ```bash
   git bisect good [older_commit_hash]
   ```

4. **Run automated bisect:**
   ```bash
   git bisect run ./my_bisect_test.sh
   ```

5. **Reset when done:**
   ```bash
   git bisect reset
   ```

## Exit Codes

The script follows git bisect conventions:

- **0** - Good commit (no error found)
- **1** - Bad commit (error found)
- **125** - Skip commit (build failed or other issue)

## Common Error Patterns

| Pattern | Use Case |
|---------|----------|
| `"not implemented"` | Unimplemented features |
| `"memory\|segmentation fault\|malloc"` | Memory issues |
| `"runtime error\|exception"` | General exceptions |
| `"assertion failed\|assert"` | Assertion failures |
| `"internal error"` | Internal DuckDB errors |
| `"timeout\|killed"` | Hanging/timeout issues |
| `"syntax error"` | Parsing problems |
| `"bind\|binding"` | Binding errors |

## Common Build Commands

| Command | Purpose |
|---------|---------|
| `"GEN=ninja make release"` | Standard release build |
| `"GEN=ninja make debug"` | Debug build |
| `"GEN=ninja make release BUILD_ICU=1"` | With ICU support |
| `"GEN=ninja make debug BUILD_SANITIZER=1"` | With sanitizers |
| `"GEN=ninja make release BUILD_PYTHON=1"` | With Python bindings |

## Tips

1. **Test your script first** - Run it manually on known good/bad commits before using with `git bisect run`

2. **Use appropriate timeouts** - Set `TIMEOUT_SECONDS` based on your query complexity

3. **Database file handling** - Use `:memory:` or empty `DB_PATH` for in-memory databases

4. **Build optimization** - Consider using `ccache` to speed up builds during bisect

5. **Logging** - The script outputs detailed information to help debug issues

## Example Complete Setup

```bash
# 1. Create your test
cp bisect_test_template.sh find_regression.sh

# 2. Edit configuration in find_regression.sh
# Set DB_PATH, SQL_FILE, ERROR_PATTERN, etc.

# 3. Create SQL test file
echo "SELECT * FROM broken_function();" > regression_test.sql

# 4. Test manually first
./find_regression.sh

# 5. Run bisect
git bisect start
git bisect bad HEAD
git bisect good v0.9.0
git bisect run ./find_regression.sh
```

This will automatically find the commit that introduced the regression!