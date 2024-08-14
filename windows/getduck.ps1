# Remove the Libraries directory if it exists
Remove-Item -Recurse -Force "./Libraries/" -ErrorAction Ignore

# Clone the repository
git clone --depth 1 --branch v1.0.0 https://github.com/duckdb/duckdb

# Move into the repository directory
Set-Location -Path "duckdb"

cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_GENERATOR_PLATFORM=x64 -DDISABLE_UNITY=1 -DBUILD_EXTENSIONS='icu;parquet;json;fts;autocomplete'
cmake --build . --config Release

# Copy the framework out
New-Item -ItemType Directory -Path "../Libraries/release/" -Force
Copy-Item "./src/Release/duckdb.dll" -Destination "../Libraries/release/"

# Cleanup
Set-Location -Path "../"
Remove-Item -Recurse -Force "duckdb"
