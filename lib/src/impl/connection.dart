part of 'implementation.dart';

/// Contains the state of a connection needed for finalization.
///
/// This is extracted into separate object so that it can be used as a
/// finalization token. It will get disposed when the main database is no longer
/// reachable without being closed.
class _FinalizableConnection extends FinalizablePart {
  final Bindings _bindings;
  final Pointer<duckdb_connection> _handle;

  _FinalizableConnection(this._bindings, this._handle);

  @override
  void dispose() {
    _bindings.duckdb_disconnect(_handle);
    _handle.free();
  }
}

class ConnectionImpl extends Connection {
  final Bindings _bindings;

  final _FinalizableConnection _finalizable;
  final Finalizer<FinalizablePart> _finalizer = disposeFinalizer;
  bool _isClosed = false;

  Pointer<duckdb_connection> get _handle => _finalizable._handle;

  ConnectionImpl._(this._bindings, Pointer<duckdb_connection> handle)
      : _finalizable = _FinalizableConnection(_bindings, handle) {
    _finalizer.attach(this, _finalizable, detach: this);
  }

  factory ConnectionImpl.connect(Database database) {
    final bindings = duckdb.bindings;
    final outConn = allocate<duckdb_connection>();

    if (bindings.duckdb_connect(
          (database.handle as Pointer<duckdb_database>).value,
          outConn,
        ) ==
        duckdb_state.DuckDBError) {
      throw DuckDBException("could not create database connection");
    }

    return ConnectionImpl._(bindings, outConn);
  }

  factory ConnectionImpl.connectWithTransferred(
    TransferableDatabaseImpl database,
  ) {
    final bindings = duckdb.bindings;
    final outConn = allocate<duckdb_connection>();

    if (bindings.duckdb_connect(
          (database.handle as Pointer<duckdb_database>).value,
          outConn,
        ) ==
        duckdb_state.DuckDBError) {
      throw DuckDBException("could not create database connection");
    }

    return ConnectionImpl._(bindings, outConn);
  }

  @override
  void dispose() {
    if (_isClosed) return;

    _finalizer.detach(this);
    _isClosed = true;

    _finalizable.dispose();
  }

  @override
  Pointer<void> get handle => _handle;

  void _ensureOpen() {
    if (_isClosed) {
      throw StateError("This connection has already been closed");
    }
  }

  @override
  ResultSet query(String query) {
    _ensureOpen();

    final result = allocate<duckdb_result>();
    final queryPtr = query.toNativeUtf8().cast<Char>();

    try {
      if (duckdb_state.DuckDBError ==
          _bindings.duckdb_query(_handle.value, queryPtr, result)) {
        throw DuckDBException(
          _bindings.duckdb_result_error(result).readString(),
        );
      }

      return ResultSetImpl.withResult(result);
    } finally {
      queryPtr.free();
    }
  }

  @override
  void execute(String query) {
    this.query(query).dispose();
  }

  @override
  PreparedStatement prepare(String query) {
    return PreparedStatementImpl.prepare(this, query);
  }

  @override
  Appender append(String table, String? schema) {
    return AppenderImpl.withConnection(this, table, schema);
  }

  @override
  Iterable<String> getColumnOrder(String table) {
    final sql = """
      SELECT column_name
      FROM information_schema.columns
      WHERE table_name = '$table'
      ORDER BY ordinal_position;
    """;

    final resultSet = query(sql);
    return resultSet.fetchAll().flattened.cast();
  }

  @override
  void interrupt() {
    _ensureOpen();
    _bindings.duckdb_interrupt(_handle.value);
  }
}
