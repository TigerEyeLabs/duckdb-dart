part of 'implementation.dart';

/// Contains the state of a database needed for finalization.
///
/// This is extracted into separate object so that it can be used as a
/// finalization token. It will get disposed when the main database is no longer
/// reachable without being closed.
class _FinalizableDatabase extends FinalizablePart {
  final Bindings _bindings;
  final Pointer<duckdb_database> _handle;
  final List<Pointer<Void>> _furtherAllocations = [];

  _FinalizableDatabase(this._bindings, this._handle);

  @override
  void dispose() {
    _bindings.duckdb_close(_handle);

    for (final additional in _furtherAllocations) {
      additional.free();
    }

    // we don't need to deallocate the _db pointer, duckdb takes care of that
  }
}

class DatabaseImpl extends Database {
  final _FinalizableDatabase _finalizable;
  final Finalizer<FinalizablePart> _finalizer = disposeFinalizer;

  bool _isClosed = false;

  DatabaseImpl(BindingsWithLibrary library, Pointer<duckdb_database> handle)
      : _finalizable = _FinalizableDatabase(library.bindings, handle) {
    _finalizer.attach(this, _finalizable, detach: this);
  }

  /// https://duckdb.org/docs/sql/configuration#configuration-reference
  factory DatabaseImpl.open(
    BindingsWithLibrary library, {
    String dbname = ':memory:',
    Map<String, String>? settings,
  }) {
    final bindings = library.bindings;
    final name = dbname.toNativeUtf8().cast<Char>();
    final errMsg = malloc<Pointer<Char>>();
    final config = malloc<duckdb_config>();
    final outDb = allocate<duckdb_database>();

    try {
      if (bindings.duckdb_create_config(config) == duckdb_state.DuckDBError) {
        throw DuckDBException("could not create database configuration");
      }

      settings?.forEach((key, value) {
        final k = key.toNativeUtf8().cast<Char>();
        final v = value.toNativeUtf8().cast<Char>();
        try {
          if (bindings.duckdb_set_config(config.value, k, v) ==
              duckdb_state.DuckDBError) {
            throw DuckDBException(
              "config error: could not set $key for $value",
            );
          }
        } finally {
          malloc.free(k);
          malloc.free(v);
        }
      });

      if (bindings.duckdb_open_ext(name, outDb, config.value, errMsg) ==
          duckdb_state.DuckDBError) {
        final msg = errMsg.value.cast<Utf8>().toDartString();
        bindings.duckdb_destroy_config(config);
        throw DuckDBException(msg);
      }

      bindings.duckdb_destroy_config(config);
    } finally {
      malloc.free(config);
      malloc.free(errMsg);
      malloc.free(name);
    }

    return DatabaseImpl(library, outDb);
  }

  Pointer<duckdb_database> get _handle => _finalizable._handle;

  @override
  Pointer<void> get handle => _handle;

  @override
  Future<void> dispose() async {
    if (_isClosed) return;

    _finalizer.detach(this);
    _isClosed = true;

    _finalizable.dispose();
  }

  @override
  TransferableDatabase get transferable =>
      TransferableDatabaseImpl(_handle.address);
}

/// A simple wrapper on the integer address of the [duckdb_database].
/// FFI pointers are Finalizers and cannot be sent to another isolate.
class TransferableDatabaseImpl extends TransferableDatabase {
  final int address;

  TransferableDatabaseImpl(this.address);

  // get the handle of the database
  Pointer<void> get handle => Pointer.fromAddress(address);
}
