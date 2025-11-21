# Script entry point
param (
    [Parameter(Mandatory = $false)]
    [string]$Command = "All"
)

# Define variables
$VERSION = "v1.4.2"
$DUCKDB_REPO = "https://github.com/duckdb/duckdb"
$DUCKDB_DIR = "duckdb"
$BUILD_DIR = "C:\tmp\ddb"
$LIB_DIR = "Libraries/release"
$EXTENSIONS = "icu;parquet;json"
$CMAKE_GENERATOR = "Visual Studio 17 2022"

# Define functions
function Reset {
    ## Remove previous build
    if (Test-Path $LIB_DIR) {
        Remove-Item -Recurse -Force $LIB_DIR
        Write-Host "Removed $LIB_DIR"
    }
    if (Test-Path $DUCKDB_DIR) {
        # Try to remove with retries to handle file locks
        $maxRetries = 3
        $retryCount = 0
        $removed = $false

        while (-not $removed -and $retryCount -lt $maxRetries) {
            try {
                # Force kill any processes that might be holding files
                Get-Process | Where-Object { $_.ProcessName -like "*cmake*" -or $_.ProcessName -like "*cl*" -or $_.ProcessName -like "*link*" } | Stop-Process -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2

                Remove-Item -Recurse -Force $DUCKDB_DIR -ErrorAction Stop
                $removed = $true
                Write-Host "Removed $DUCKDB_DIR"
            }
            catch {
                $retryCount++
                if ($retryCount -lt $maxRetries) {
                    Write-Host "Failed to remove $DUCKDB_DIR, retrying in 5 seconds... (attempt $retryCount/$maxRetries)"
                    Start-Sleep -Seconds 5
                } else {
                    Write-Warning "Could not completely remove $DUCKDB_DIR after $maxRetries attempts. Some files may be locked."
                    # Try to at least remove what we can
                    Get-ChildItem $DUCKDB_DIR -Recurse -Force | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                }
            }
        }
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

    # Verify build tools are available
    Write-Host "Verifying build tools..."Show environment diagnostics
    Write-Host "Environment Diagnostics:"
    Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)"
    Write-Host "OS Version: $([Environment]::OSVersion.VersionString)"
    Write-Host "Architecture: $([Environment]::GetEnvironmentVariable('PROCESSOR_ARCHITECTURE'))"

    # Check CMake version
    try {
        $cmakeVersion = & cmake --version 2>&1
        Write-Host "CMake Version:"
        $cmakeVersion | ForEach-Object { Write-Host $_ }
    } catch {
        Write-Error "CMake not found in PATH"
        return
    }

    # Check Visual Studio installation
    try {
        $vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
        if (Test-Path $vsWhere) {
            $vsInstallations = & $vsWhere -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
            Write-Host "Visual Studio installations found:"
            $vsInstallations | ForEach-Object { Write-Host "  $_" }
        } else {
            Write-Host "vswhere.exe not found - Visual Studio detection skipped"
        }
    } catch {
        Write-Host "Could not detect Visual Studio installations"
    }

    # Verify DuckDB source structure
    Write-Host "Verifying DuckDB source structure..."
    $cmakeListsPath = Join-Path $DUCKDB_DIR "CMakeLists.txt"
    $srcPath = Join-Path $DUCKDB_DIR "src"

    if (-not (Test-Path $cmakeListsPath)) {
        Write-Error "CMakeLists.txt not found at $cmakeListsPath"
        return
    }

    if (-not (Test-Path $srcPath)) {
        Write-Error "src directory not found at $srcPath"
        return
    }

    Write-Host "DuckDB source structure verified:"
    Write-Host "  CMakeLists.txt: $(Test-Path $cmakeListsPath)"
    Write-Host "  src directory: $(Test-Path $srcPath)"

    # Show key source files
    Write-Host "Key source contents:"
    Get-ChildItem $DUCKDB_DIR | Select-Object Name, Length | Format-Table -AutoSize

    # Get absolute path to DuckDB source before changing directories
    $sourceDir = Resolve-Path $DUCKDB_DIR

    # Create very short build directory to avoid Windows path limits
    if (Test-Path $BUILD_DIR) {
        Remove-Item -Recurse -Force $BUILD_DIR -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $BUILD_DIR -Force | Out-Null
    Write-Host "Created build directory at $BUILD_DIR"

    # Run CMake to configure the project
    Push-Location -Path $BUILD_DIR

    Write-Host "Running CMake configuration..."
    Write-Host "Current directory: $(Get-Location)"
    Write-Host "DuckDB source directory: $sourceDir"
    Write-Host "DuckDB source directory contents:"
    Get-ChildItem $sourceDir | Select-Object Name, Length | Format-Table -AutoSize

    # Configure with CMake - capture output for debugging
    Write-Host "Running CMake configuration command:"
    Write-Host "cmake -G `"$CMAKE_GENERATOR`" -A x64 -DCMAKE_BUILD_TYPE=Release -DBUILD_EXTENSIONS=`"$EXTENSIONS`" -DBUILD_SHELL=0 $sourceDir"

    # Use direct cmake invocation to avoid argument parsing issues
    $cmakeOutput = & cmake -G $CMAKE_GENERATOR -A x64 -DCMAKE_BUILD_TYPE=Release -DBUILD_EXTENSIONS="$EXTENSIONS" -DBUILD_SHELL=0 $sourceDir 2>&1
    $cmakeExitCode = $LASTEXITCODE

    # Show configuration output
    Write-Host "CMake configuration output:"
    $cmakeOutput | ForEach-Object { Write-Host $_ }

    if ($cmakeExitCode -ne 0) {
        Pop-Location
        Write-Error "CMake configuration failed with exit code $cmakeExitCode"
        return
    }
    Write-Host "CMake configuration completed successfully."

    # Verify build directory state after configuration
    Write-Host "Verifying build directory state..."
    $cmakeCachePath = "CMakeCache.txt"
    $cmakeFilesPath = "CMakeFiles"

    if (-not (Test-Path $cmakeCachePath)) {
        Write-Error "CMakeCache.txt not found in build directory"
        Pop-Location
        return
    }

    if (-not (Test-Path $cmakeFilesPath)) {
        Write-Error "CMakeFiles directory not found in build directory"
        Pop-Location
        return
    }

    Write-Host "Build directory verification passed:"
    Write-Host "  CMakeCache.txt: $(Test-Path $cmakeCachePath)"
    Write-Host "  CMakeFiles directory: $(Test-Path $cmakeFilesPath)"

    # Show cache file size for debugging
    $cacheSize = (Get-Item $cmakeCachePath).Length
    Write-Host "  CMakeCache.txt size: $cacheSize bytes"

    # Determine the number of processors for parallel build
    $numberOfProcessors = [Environment]::GetEnvironmentVariable("NUMBER_OF_PROCESSORS")
    if (-not $numberOfProcessors) {
        $numberOfProcessors = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
    }

    # Build the project with verbose output and real-time display
    Write-Host "Starting CMake build with $numberOfProcessors processors..."
    Write-Host "Current directory for build: $(Get-Location)"

    # Verify we're in the correct build directory
    $currentPath = Get-Location
    if ($currentPath.Path -ne $BUILD_DIR) {
        Write-Error "Not in correct build directory. Current: $currentPath, Expected: $BUILD_DIR"
        Pop-Location
        return
    }

    # Check path lengths before build
    $currentDir = (Get-Location).Path
    Write-Host "Pre-build path length check:"
    Write-Host "  Current directory: $currentDir (length: $($currentDir.Length))"
    Write-Host "  Estimated longest build path would be around: $($currentDir.Length + 100) characters"

    if ($currentDir.Length -gt 120) {
        Write-Warning "Build directory path is quite long ($($currentDir.Length) chars). This may cause issues with Windows 260-char path limit."
    }

    Write-Host "Build command: cmake --build . --config Release --parallel $numberOfProcessors --verbose"

    # Use direct cmake invocation like we did for configuration
    Write-Host "Executing build command..."
    $buildOutput = & cmake --build "." --config Release --parallel $numberOfProcessors --verbose 2>&1
    $buildExitCode = $LASTEXITCODE

    # Display build output
    Write-Host "Build output:"
    $buildOutput | ForEach-Object { Write-Host $_ }



    if ($buildExitCode -ne 0) {
        Pop-Location
        Write-Host "Build failed with exit code $buildExitCode" -ForegroundColor Red

        # Check for specific error patterns
        $linkErrors = $buildOutput | Where-Object { $_ -match "LNK\d+|fatal error|error C\d+|Error:" }
        if ($linkErrors) {
            Write-Host "`nSpecific errors found:" -ForegroundColor Red
            $linkErrors | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
        }

        Write-Error "CMake build failed with exit code $buildExitCode"
        return
    }
    Write-Host "Build completed successfully with $numberOfProcessors processors."

    Pop-Location

    # Create Libraries/release directory
    if (-not (Test-Path $LIB_DIR)) {
        New-Item -ItemType Directory -Path $LIB_DIR | Out-Null
        Write-Host "Created library directory at $LIB_DIR"
    }

    # Copy the built duckdb.dll to Libraries/release
    $dllSource = Join-Path $BUILD_DIR "src\Release\duckdb.dll"
    $dllDestination = Join-Path $LIB_DIR "duckdb.dll"

    # Debug path lengths
    Write-Host "Path length debugging:"
    Write-Host "  Build directory: $BUILD_DIR (length: $($BUILD_DIR.Length))"
    Write-Host "  DLL source path: $dllSource (length: $($dllSource.Length))"
    Write-Host "  Current working directory: $(Get-Location) (length: $((Get-Location).Path.Length))"

    if (Test-Path $dllSource) {
        Copy-Item -Path $dllSource -Destination $dllDestination -Force
        Write-Host "Copied duckdb.dll to $LIB_DIR"
    } else {
        Write-Error "duckdb.dll not found at $dllSource"
        Write-Host "Looking for DLL in build directory..."
        Get-ChildItem $BUILD_DIR -Recurse -Name "*.dll" | ForEach-Object {
            $fullPath = Join-Path $BUILD_DIR $_
            Write-Host "Found: $_ (full path length: $($fullPath.Length))"
        }
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
