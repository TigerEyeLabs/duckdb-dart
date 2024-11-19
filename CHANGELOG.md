## 1.0.0

- Initial version.

## 1.0.1

- Fixes to publish to pub.dev

## 1.0.2

- Download android/windows/linux/macos duckdb builds during building if missing.

## 1.0.3

- Minor documentation updates.

## 1.1.0

- Added support for duckdb's pending results, enabling cancellable queries.

## 1.1.3

- Added support for all duckdb datatypes.
- Full Value support for PreparedStatements.
- Leverage Dart generics for vectors and values classes.
- Added support for streaming query results.
- Smaller android binaries by removing unused symbols.
- Improved query performance via faster datachunk indexing via galloping search.
