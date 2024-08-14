/// A Dart library for interfacing with the DuckDB database engine.
///
/// This library provides a high-level, idiomatic Dart interface for
/// interacting with DuckDB, an in-process SQL OLAP database management system.
/// It includes support for executing queries, fetching results, and managing
/// transactions.
///
/// To use this library in your code:
/// ```dart
/// import 'package:dart_duckdb/dart_duckdb.dart';
/// ```
library dart_duckdb;

import 'package:dart_duckdb/src/api/connection.dart';
import 'package:dart_duckdb/src/api/database.dart';
import 'package:dart_duckdb/src/api/duckdb.dart' as api;
import 'package:dart_duckdb/src/ffi/ffi.dart';
import 'package:dart_duckdb/src/ffi/load_library.dart';
import 'package:dart_duckdb/src/impl/implementation.dart';

export 'src/api/appender.dart';
export 'src/api/connection.dart';
export 'src/api/database.dart';
export 'src/api/database_type.dart';
export 'src/api/exception.dart';
export 'src/api/prepared_statement.dart';
export 'src/api/result_set.dart';
export 'src/types/date.dart';
export 'src/types/decimal.dart';
export 'src/types/interval.dart';

class DuckDB extends api.DuckDB {
  static DuckDB? instance;

  // Registers this class as the default instance of [DuckDB]
  static void registerWith() {
    DuckDB.instance = duckdb;
  }

  final BindingsWithLibrary _library;
  Bindings get bindings => _library.bindings;

  /// Loads `duckdb` bindings by looking up functions in the [library].
  ///
  /// If application-defined functions are used, there shouldn't be multiple
  /// [DuckDB] objects with a different underlying [library].
  DuckDB._(DynamicLibrary library) : _library = BindingsWithLibrary(library);

  /// Open a database, if the database does not exist, it will be created.
  /// Use :memory: to create an in-memory database.
  @override
  Database open(String filename, {Map<String, String>? settings}) {
    return DatabaseImpl.open(_library, dbname: filename, settings: settings);
  }

  /// Create a connection to the database.
  @override
  Connection connect(Database database) {
    return ConnectionImpl.connect(database);
  }

  /// Create a connection to the database with a [TransferableDatabase].
  @override
  Connection connectWithTransferred(
    TransferableDatabase transferableDatabase,
  ) {
    /// Creating a Dart representation of the native pointer. No need to free it.
    return ConnectionImpl.connectWithTransferred(
      transferableDatabase as TransferableDatabaseImpl,
    );
  }

  /// The version of the duckdb library in used.
  @override
  String get version {
    return bindings.duckdb_library_version().readString();
  }
}

DuckDB? _duckDB;

/// Provides access to `duckdb` functions, such as opening new databases.
DuckDB get duckdb {
  return _duckDB ??= DuckDB._(open.openDuckDB());
}
