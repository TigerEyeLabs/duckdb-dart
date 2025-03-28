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
library;

import 'dart:ffi';

import 'package:dart_duckdb/src/api/connection.dart';
import 'package:dart_duckdb/src/api/database.dart';
import 'package:dart_duckdb/src/api/duckdb.dart' as api;
import 'package:dart_duckdb/src/ffi/duckdb.g.dart';
import 'package:dart_duckdb/src/ffi/impl/implementation.dart';
import 'package:dart_duckdb/src/ffi/impl/utils.dart';
import 'package:dart_duckdb/src/ffi/load_library.dart' as load;

class BindingsWithLibrary {
  final Bindings bindings;
  final DynamicLibrary library;

  BindingsWithLibrary(this.library) : bindings = Bindings(library);
}

class DuckDB extends api.DuckDB {
  static DuckDB? instance;

  final BindingsWithLibrary _library;
  @override
  Bindings get bindings => _library.bindings;

  DuckDB._internal()
      : _library = BindingsWithLibrary(
          (load.open as load.OpenDynamicLibrary).openDuckDB(),
        );

  // Registers this class as the default instance of [DuckDB]
  static void registerWith() {
    DuckDB.instance = duckdb as DuckDB?;
  }

  /// Open a database, if the database does not exist, it will be created.
  /// Use :memory: to create an in-memory database.
  @override
  Future<Database> open(
    String filename, {
    Map<String, String>? settings,
  }) async {
    return DatabaseImpl.open(_library, dbname: filename, settings: settings)
        as Database;
  }

  /// Create a connection to the database.
  @override
  Future<Connection> connect(Database database, {String? id}) async {
    return ConnectionImpl.connect(database, id: id);
  }

  /// Create a connection to the database with a [TransferableDatabase].
  @override
  Future<Connection> connectWithTransferred(
    TransferableDatabase transferableDatabase, {
    String? id,
  }) async {
    return ConnectionImpl.connectWithTransferred(
      transferableDatabase as TransferableDatabaseImpl,
      id: id,
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
api.DuckDB get duckdb {
  return _duckDB ??= DuckDB._internal();
}
