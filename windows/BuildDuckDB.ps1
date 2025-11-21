# Script entry point
param (
    [Parameter(Mandatory = $false)]
    [string]$Command = "All"
)

# Define variables
$VERSION = "v1.4.2"
$DUCKDB_REPO = "https://github.com/duckdb/duckdb"
$DUCKDB_DIR = "duckdb"
$BUILD_DIR = Join-Path $DUCKDB_DIR "build"
$LIB_DIR = "Libraries/release"
$EXTENSIONS = "icu;parquet;json;fts;autocomplete"
$CMAKE_GENERATOR = "Visual Studio 17 2022"

# Define functions
function Reset {
    ## Remove previous build
    if (Test-Path $LIB_DIR) {
        Remove-Item -Recurse -Force $LIB_DIR
        Write-Host "Removed $LIB_DIR"
    }
    if (Test-Path $DUCKDB_DIR) {
        Remove-Item -Recurse -Force $DUCKDB_DIR
        Write-Host "Removed $DUCKDB_DIR"
    }
}

function Clone-DuckDB {
    ## Clone DuckDB repository
    if (-not (Test-Path $DUCKDB_DIR)) {
        git clone --depth 1 --branch $VERSION $DUCKDB_REPO $DUCKDB_DIR
        Write-Host "Cloned DuckDB repository at $VERSION"
    } else {
        Write-Host "DuckDB directory already exists. Skipping clone."
    }
}

function Release-Build {
    ## x64 Windows build
    Clone-DuckDB

    # Create build directory
    if (-not (Test-Path $BUILD_DIR)) {
        New-Item -ItemType Directory -Path $BUILD_DIR | Out-Null
        Write-Host "Created build directory at $BUILD_DIR"
    }

    # Run CMake to configure the project
    Push-Location -Path $BUILD_DIR
    & cmake -G $CMAKE_GENERATOR  -A x64 `
        -DCMAKE_BUILD_TYPE=Release `
        -DBUILD_EXTENSIONS="$EXTENSIONS" `
        -DBUILD_SHELL=0 `
        ".."
    Write-Host "CMake configuration completed."

    # Determine the number of processors for parallel build
    $numberOfProcessors = [Environment]::GetEnvironmentVariable("NUMBER_OF_PROCESSORS")
    if (-not $numberOfProcessors) {
        $numberOfProcessors = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
    }

    # Build the project
    & cmake --build . --config Release --parallel $numberOfProcessors
    Write-Host "Build completed with $numberOfProcessors processors."

    Pop-Location

    # Create Libraries/release directory
    if (-not (Test-Path $LIB_DIR)) {
        New-Item -ItemType Directory -Path $LIB_DIR | Out-Null
        Write-Host "Created library directory at $LIB_DIR"
    }

    # Copy the built duckdb.dll to Libraries/release
    $dllSource = Join-Path $BUILD_DIR "src\Release\duckdb.dll"
    $dllDestination = Join-Path $LIB_DIR "duckdb.dll"
    if (Test-Path $dllSource) {
        Copy-Item -Path $dllSource -Destination $dllDestination -Force
        Write-Host "Copied duckdb.dll to $LIB_DIR"
    } else {
        Write-Error "duckdb.dll not found at $dllSource"
    }
}

function Clean {
    ## Clean the build directory
    if (Test-Path $BUILD_DIR) {
        Remove-Item -Recurse -Force $BUILD_DIR
        Write-Host "Cleaned build directory at $BUILD_DIR"
    } else {
        Write-Host "Build directory does not exist. Nothing to clean."
    }
}

function Show-Help {
    ## Display help message
    Write-Host "Available commands:"
    Write-Host "Reset           - Remove previous build"
    Write-Host "Clone-DuckDB    - Clone DuckDB repository"
    Write-Host "Release-Build   - Build the project for Windows x64"
    Write-Host "Clean           - Clean the build directory"
    Write-Host "Show-Help       - Display this help message"
}

function All {
    ## Default target: reset and release build
    Reset
    Release-Build
}

# Execute command
switch ($Command.ToLower()) {
    "reset"         { Reset }
    "duckdb"        { Clone-DuckDB }
    "release"       { Release-Build }
    "clean"         { Clean }
    "help"          { Show-Help }
    "all"           { All }
    default         { Show-Help }
}
