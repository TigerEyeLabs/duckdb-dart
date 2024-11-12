# Script entry point
param (
    [Parameter(Mandatory=$false)]
    [string]$Command = "Release-Build"
)

# Define variables
$VERSION = "v1.1.3"
$DUCKDB_REPO = "https://github.com/duckdb/duckdb"
$DUCKDB_DIR = "duckdb"
$BUILD_DIR = Join-Path $DUCKDB_DIR "build"
$EXTENSION_DIR = Join-Path $DUCKDB_DIR "extension"
$LIB_DIR = "Libraries/release"
$EXTENSIONS = "icu;parquet;json;fts;autocomplete"
$CMAKE_GENERATOR = "Visual Studio 17 2022"

if (-not $env:VCPKG_TOOLCHAIN_PATH) {
    Write-Error "VCPKG_TOOLCHAIN_PATH is not set"
    exit 1
}

# Define functions
function Reset-BuildEnvironment {
    # Only remove the release library to avoid full rebuilds
    if (Test-Path $LIB_DIR) { Remove-Item -Recurse -Force $LIB_DIR }
    if (Test-Path $DUCKDB_DIR) { Remove-Item -Recurse -Force $DUCKDB_DIR }
}

function Clone-DuckDB {
    # Shallow clone DuckDB repo and checkout specific commit
    if (-not (Test-Path $DUCKDB_DIR)) {
        git clone --depth 1 --branch $VERSION $DUCKDB_REPO $DUCKDB_DIR
        Copy-Item -Path "extension_config_local.cmake" -Destination $EXTENSION_DIR -Force
    }
}

function Build-DuckDB {
    Reset-BuildEnvironment
    Clone-DuckDB

    # (Optional) If 'windows_ci.py' causes conflicts, comment it out
    Push-Location -Path $DUCKDB_DIR
    & "python" "scripts/windows_ci.py"
    Pop-Location

    # Create build directory
    if (-not (Test-Path $BUILD_DIR)) {
        New-Item -ItemType Directory -Path $BUILD_DIR | Out-Null
    }

    # Run CMake to configure the project
    Push-Location -Path $BUILD_DIR
    & "cmake" -G $CMAKE_GENERATOR -A x64 `
        -DSPATIAL_USE_NETWORK=OFF `
        -DDUCKDB_EXPLICIT_PLATFORM=windows_amd64 `
        -DCMAKE_BUILD_TYPE=Release `
        -DBUILD_EXTENSIONS="$($EXTENSIONS)" `
        -DENABLE_EXTENSION_AUTOLOADING=0 `
        -DENABLE_EXTENSION_AUTOINSTALL=0 `
        -DBUILD_LOADABLE_EXTENSIONS=0 `
        -DEXTENSION_STATIC_BUILD=1 `
        -DCMAKE_CXX_STANDARD=17 `
        -DCMAKE_CXX_STANDARD_REQUIRED=ON `
        -DBUILD_UNITTESTS=0 `
        -DBUILD_SHELL=0 `
        -DDISABLE_UNITY=1 `
        -DCMAKE_TOOLCHAIN_FILE="$env:VCPKG_TOOLCHAIN_PATH" `
        -DVCPKG_FEATURE_FLAGS=manifests `
        ..

    # Build extension configuration
    $extensionConfigDir = Join-Path $BUILD_DIR "extension_configuration"
    if (-not (Test-Path $extensionConfigDir)) {
        New-Item -ItemType Directory -Path $extensionConfigDir | Out-Null
    }
    Push-Location -Path $extensionConfigDir
    & "cmake" -G $CMAKE_GENERATOR `
        -DEXTENSION_CONFIG_BUILD=TRUE `
        -DCMAKE_BUILD_TYPE=Release `
        "../.."
    & "cmake" --build . --config Release -- /maxcpucount:$env:NUMBER_OF_PROCESSORS
    Pop-Location

    # Build the main project
    $env:CMAKE_BUILD_PARALLEL_LEVEL = $env:NUMBER_OF_PROCESSORS
    & "cmake" --build . --config Release -- /maxcpucount:$env:NUMBER_OF_PROCESSORS

    # Copy the output to the library directory
    if (-not (Test-Path $LIB_DIR)) { New-Item -ItemType Directory -Path $LIB_DIR | Out-Null }
    Copy-Item -Path "$BUILD_DIR\src\Release\duckdb.dll" -Destination "$LIB_DIR\duckdb.dll" -Force
    Pop-Location
}

function Release-Build {
    Reset-BuildEnvironment
    Build-DuckDB
    Write-Host "Windows Release Build Complete"
}

# Help function
function Show-Help {
    Write-Host "Available commands:"
    Write-Host "Reset-BuildEnvironment - Reset build environment"
    Write-Host "Clone-DuckDB - Clone DuckDB repository and configure"
    Write-Host "Build-DuckDB - Build the DuckDB project"
    Write-Host "Release-Build - Build and release the project for Windows"
    Write-Host "Show-Help - Display this help message"
}

# Execute command
switch ($Command) {
    "reset" { Reset-BuildEnvironment }
    "duckdb" { Clone-DuckDB }
    "build" { Build-DuckDB }
    "release" { Release-Build }
    "help" { Show-Help }
    default { Show-Help }
}
