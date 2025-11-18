import 'dart:typed_data';

import 'package:dart_duckdb/src/types/protocol.dart';

/// An opened duckdb database with `dart:ffi`.
abstract class Database {
  /// The native database connection handle from duckdb.
  ///
  /// This returns a pointer towards the opaque duckdb structure as defined
  dynamic get handle;

  /// An unmanaged database reference that can be sent across isolate boundaries.
  /// Disposing the source database, will invalidate this TransferableDatabase.
  ///
  /// Use this to create [Connection]s on separate isolates.
  /// It is recommended to have a single connection per isolate.
  TransferableDatabase get transferable;

  /// Register a file buffer with the database.
  /// This is only for duckdb-wasm.
  Future<void> registerFileBuffer(String name, Uint8List buffer);

  /// Register a file URL with the database.
  /// This is only for duckdb-wasm.
  Future<void> registerFileURL(
    String name,
    String url,
    DuckDBDataProtocol protocol,
    bool directIO,
  );

  /// Register a file handle with the database.
  /// This is only for duckdb-wasm.
  Future<void> registerFileHandle(
    String name,
    dynamic handle,
    DuckDBDataProtocol protocol,
    bool directIO,
  );

  /// Closes this database and releases associated resources.
  Future<void> dispose();
}

/// A database weak reference that can be sent across isolate boundaries.
abstract class TransferableDatabase {}
