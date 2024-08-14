import 'dart:ffi';

/// An opened duckdb database with `dart:ffi`.
abstract class Database {
  /// The native database connection handle from duckdb.
  ///
  /// This returns a pointer towards the opaque duckdb structure as defined
  Pointer<void> get handle;

  /// An unmanaged database reference that can be sent across isolate boundaries.
  /// Disposing the source database, will invalidate this TransferableDatabase.
  ///
  /// Use this to create [Connection]s on separate isolates.
  /// It is recommended to have a single connection per isolate.
  TransferableDatabase get transferrable;

  /// Closes this database and releases associated resources.
  void dispose();
}

/// A database weak reference that can be sent across isolate boundaries.
abstract class TransferableDatabase {}
