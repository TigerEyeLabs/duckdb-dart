# DuckDB.Dart

**DuckDB.Dart** is the native Dart API for [DuckDB](https://duckdb.org/), enabling developers to harness the power of DuckDB in Dart-based applications across Apple, iOS, Android, Linux, and Windows platforms.

## DuckDB Overview

DuckDB is a high-performance analytical database system known for its speed, reliability, and ease of use. It supports a comprehensive SQL dialect, offering features such as:

- Arbitrary and nested correlated subqueries
- Window functions
- Collations
- Complex types (arrays, structs)

For more information on DuckDB's goals and capabilities, visit the [Why DuckDB page](https://duckdb.org/why_duckdb).
# DuckDB.Dart

**DuckDB.Dart** is the native Dart API for [DuckDB](https://duckdb.org/), enabling developers to harness the power of DuckDB in Dart-based applications across Apple, iOS, Android, Linux, and Windows platforms.

## DuckDB Overview

DuckDB is a high-performance analytical database system known for its speed, reliability, and ease of use. It supports a comprehensive SQL dialect, offering features such as:

- Arbitrary and nested correlated subqueries
- Window functions
- Collations
- Complex types (arrays, structs)

For more information on DuckDB's goals and capabilities, visit the [Why DuckDB page](https://duckdb.org/why_duckdb).

## Building DuckDB.dart

- Setup Dart SDK, [Getting Started](https://dart.dev/get-dart)
- Install FVM, [Getting Started](https://fvm.app/documentation/getting-started/installation)
- Run Flutter Doctor to ensure everything is setup correctly. `fvm flutter doctor`
- `make build`

### Android Builds

- Android Studio is required to build the Android binaries, [Install Studio](https://developer.android.com/studio).
- JDK 17 is required to build the Android binaries.

Here are the step-by-step instructions to install JDK 17 using SDKMAN:

1. First, install SDKMAN if you haven't already:
```bash
curl -s "https://get.sdkman.io" | bash
```

2. Open a new terminal or source SDKMAN in your current terminal:
```bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
```

3. Verify SDKMAN is installed:
```bash
sdk version
```

4. List available Java versions:
```bash
sdk list java
```

5. Install JDK 17 (you can choose between different distributions like Oracle, Amazon Corretto, Eclipse Temurin, etc.):

Note: The exact version numbers might change over time. Use `sdk list java` to see the latest available versions.

For Temurin (OpenJ9):
```bash
sdk install java 17.0.12-tem
```

6. Verify the installation:
```bash
java -version
```

7. Set JDK 17 as default (optional):
```bash
sdk default java 17.0.12-tem
```

*Note:* If you see
`"Could not resolve all files for configuration ':dart_duckdb:androidJdkImage'"`

try configuring flutter
```
flutter config --jdk-dir=PATH_TO_JDK_17
```

## Usage Examples

Here are some common use cases for DuckDB.Dart:

### Querying a Database

```dart
import 'package:dart_duckdb/dart_duckdb.dart';

void main() {
  final db = duckdb.open(":memory:");
  final connection = duckdb.connect(db);

  connection.execute('''
    CREATE TABLE users (id INTEGER, name VARCHAR, age INTEGER);
    INSERT INTO users VALUES (1, 'Alice', 30), (2, 'Bob', 25);
  ''');

  final result = connection.query("SELECT * FROM users WHERE age > 28").fetchAll();

  for (final row in result) {
    print(row);
  }

  connection.dispose();
  db.dispose();
}
```

### Queries on background Isolates

```dart
import 'package:dart_duckdb/dart_duckdb.dart';

void main() {
  final db = duckdb.open(":memory:");
  final connection = duckdb.connect(db);

  await Isolate.spawn(backgroundTask, db.transferrable);

  connection.dispose();
  db.dispose();
}

void backgroundTask(TransferableDatabase transferableDb) {
  final connection = duckdb.connectWithTransferred(transferableDb);
  // Access database ...
  // fetch is needed to send the data back to the main isolate
}

```

## Contributing

We welcome contributions to DuckDB.Dart! If you have suggestions for improvements or bug fixes, please follow these steps:

1. Fork the repository.
2. Create a new branch for your feature or bug fix.
3. Make your changes and commit them with descriptive messages.
4. Push your changes to your fork.
5. Create a pull request with a detailed description of your changes.

## Support and Contact

If you encounter any issues or have questions, please check our [issue tracker](https://github.com/TigerEyeLabs/duckdb-dart/issues)

---


## Building DuckDB.Dart from Source

### Install Dependencies

Install fvm, [Getting Started](https://fvm.app/documentation/getting-started/installation)

Install any platform dependencies for DuckDB. Here are the [DuckDB Building Instructions](https://duckdb.org/docs/dev/building/build_instructions.html). Also, the github workflows are the best examples to learn from.

### Build DuckDB

Run make from this project to build/patch duckdb.

#### MacOS Universal

To build for MacOS:

```sh
make macos
```

#### iOS (Requires iOS SDK)

To build for an iOS device:

```sh
make ios_device
```

To build for an iOS simulator:

```sh
make ios_simulator
```

#### Android (Requires Android NDK)

To build for Android:

```sh
make android
```

#### Windows (Requires MINGW64)

```sh
cd windows && ./getduck.ps1
```

#### Linux

To build for Linux:

```sh
make linux
```

### Build DuckDB.Dart

```sh
make build
```
