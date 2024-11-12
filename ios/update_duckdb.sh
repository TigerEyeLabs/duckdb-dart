#!/bin/bash
# Check if two arguments are provided
if [ $# -ne 2 ]; then
    echo "Usage: $0 <old_version> <new_version>"
    echo "Example: $0 v1.0.0 v1.1.0"
    exit 1
fi

# Set version variables from arguments
OLD_VERSION=$1
NEW_VERSION=$2

# Clone DuckDB repository
git clone https://github.com/duckdb/duckdb && cd duckdb

# Fetch tags
git fetch --tags

# Checkout old version and apply changes
git checkout tags/$OLD_VERSION
git apply ../changes.patch
git add . && git commit -m 'Apply previous changes'

# Rebase to new version
git rebase tags/$NEW_VERSION

# Create updated patch file
git diff tags/$NEW_VERSION > ../changes.patch

echo "DuckDB updated from $OLD_VERSION to $NEW_VERSION"
echo "New patch file created: ../changes.patch"
