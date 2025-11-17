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

class ConnectionImpl extends Connection with DatabaseOperationCancellation {
  static final _log = Logger('duckdb');
  final Bindings _bindings;
  final _FinalizableConnection _finalizable;
  final Finalizer<FinalizablePart> _finalizer = disposeFinalizer;
  late final ConnectionIsolate _isolate;
  bool _isClosed = false;

  Pointer<duckdb_connection> get _handle => _finalizable._handle;

  @override
  Bindings get bindings => _bindings;

  @override
  ConnectionIsolate get isolate => _isolate;

  @override
  Pointer<duckdb_connection> get handle => _handle;

  @override
  String? get id => _isolate._debugId;

  static void _initializeLogging() {
    hierarchicalLoggingEnabled = true;
  }

  static Future<ConnectionImpl> create(
    Bindings bindings,
    Pointer<duckdb_connection> handle, {
    bool isTransferred = false,
    String? id,
  }) async {
    _initializeLogging();
    final conn = ConnectionImpl._(bindings, handle);
    _log.fine('Creating new connection...');
    conn._isolate = await ConnectionIsolate.create(id: id);
    _log.fine(
      'Created [Connection:${conn._isolate._debugId}${isTransferred ? ':transferred' : ':new'}]',
    );
    return conn;
  }

  ConnectionImpl._(this._bindings, Pointer<duckdb_connection> handle)
      : _finalizable = _FinalizableConnection(_bindings, handle) {
    _finalizer.attach(this, _finalizable, detach: this);
  }

  static Future<ConnectionImpl> connect(
    Database database, {
    String? id,
  }) async {
    final bindings = (duckdb as DuckDB).bindings;
    final outConn = allocate<duckdb_connection>();

    if (bindings.duckdb_connect(
          (database.handle as Pointer<duckdb_database>).value,
          outConn,
        ) ==
        duckdb_state.DuckDBError) {
      throw DuckDBException("could not create database connection");
    }

    return ConnectionImpl.create(
      bindings,
      outConn,
      isTransferred: false,
      id: id,
    );
  }

  static Future<ConnectionImpl> connectWithTransferred(
    TransferableDatabaseImpl database, {
    String? id,
  }) async {
    final bindings = (duckdb as DuckDB).bindings;
    final outConn = allocate<duckdb_connection>();

    if (bindings.duckdb_connect(
          (database.handle as Pointer<duckdb_database>).value,
          outConn,
        ) ==
        duckdb_state.DuckDBError) {
      throw DuckDBException("could not create database connection");
    }

    return ConnectionImpl.create(
      bindings,
      outConn,
      isTransferred: true,
      id: id,
    );
  }

  @override
  Future<void> dispose() async {
    if (_isClosed) {
      _log.fine('Already closed [Connection:${_isolate._debugId}]');
      return;
    }

    _log.fine('Starting dispose... [Connection:${_isolate._debugId}]');
    try {
      // First mark as closed to prevent new operations
      _isClosed = true;

      // Interrupt any ongoing operations
      _log.fine(
        'Interrupting DuckDB connection... [Connection:${_isolate._debugId}]',
      );
      _bindings.duckdb_interrupt(_handle.value);

      // Dispose the database isolate first to prevent new operations from being queued
      _log.fine(
        'Disposing connection isolate... [Connection:${_isolate._debugId}]',
      );
      await _isolate.dispose();

      // Finally detach the finalizer and dispose the connection
      _log.fine('Closing connection... [Connection:${_isolate._debugId}]');
      _finalizer.detach(this);
      _finalizable.dispose();
    } catch (e, st) {
      _log.severe(
        'Error during dispose [Connection:${_isolate._debugId}]',
        e,
        st,
      );
      _isClosed = true;
    }
  }

  void _ensureOpen() {
    if (_isClosed) {
      throw StateError("This connection has already been closed");
    }
  }

  @override
  Future<ResultSet> query(
    String query, {
    DuckDBCancellationToken? token,
  }) async {
    _ensureOpen();

    return runWithCancellation(
      operation: QueryOperation(
        connectionPointer: _handle.address,
        query: query,
      ),
      processResult: (future) async {
        final resultPointer = await future;
        final result = Pointer<duckdb_result>.fromAddress(resultPointer);

        final error = _bindings.duckdb_result_error(result);
        if (!error.isNullPointer) {
          try {
            final errorString = error.readString();
            throw DuckDBException(errorString);
          } finally {
            _bindings.duckdb_destroy_result(result);
          }
        }
        return ResultSetImpl.withResult(result);
      },
      operationDescription: query,
      token: token,
    );
  }

  @override
  Future<void> execute(
    String query, {
    DuckDBCancellationToken? token,
  }) async {
    _ensureOpen();

    return runWithCancellation(
      operation: QueryOperation(
        connectionPointer: _handle.address,
        query: query,
      ),
      processResult: (future) async {
        final resultPointer = await future;
        final result = Pointer<duckdb_result>.fromAddress(resultPointer);
        try {
          // Check for errors but discard the result
          final error = _bindings.duckdb_result_error(result);
          if (!error.isNullPointer) {
            final errorString = error.readString();
            throw DuckDBException(errorString);
          }
        } finally {
          _bindings.duckdb_destroy_result(result);
        }
      },
      operationDescription: query,
      token: token,
    );
  }

  @override
  Future<PreparedStatement> prepare(
    String query, {
    DuckDBCancellationToken? token,
  }) async {
    _ensureOpen();
    return PreparedStatementImpl.prepare(this, query, token: token);
  }

  @override
  Future<Appender> append(String table, String? schema) async {
    _ensureOpen();
    return AppenderImpl.withConnection(this, table, schema);
  }

  @override
  Future<Iterable<String>> getColumnOrder(String table) async {
    final sql = """
      SELECT column_name
      FROM information_schema.columns
      WHERE table_name = '$table'
      ORDER BY ordinal_position;
    """;

    final resultSet = await query(sql);
    try {
      return resultSet
          .fetchAll()
          .map((row) => row[0]! as String)
          .toList(growable: false);
    } finally {
      await resultSet.dispose();
    }
  }

  @override
  Future<void> interrupt() async {
    _ensureOpen();
    _bindings.duckdb_interrupt(_handle.value);
  }
}

class QueryOperation extends DatabaseOperation {
  final String query;

  const QueryOperation({
    required super.connectionPointer,
    required this.query,
  });

  @override
  Future<int> execute() async {
    final bindings = (duckdb as DuckDB).bindings;
    final connection =
        Pointer<duckdb_connection>.fromAddress(connectionPointer);
    final result = allocate<duckdb_result>();
    final queryPtr = query.toNativeUtf8().cast<Char>();

    try {
      if (bindings.duckdb_query(connection.value, queryPtr, result) ==
          duckdb_state.DuckDBError) {
        try {
          final errorString = bindings.duckdb_result_error(result).readString();
          throw DuckDBException(errorString);
        } finally {
          bindings.duckdb_destroy_result(result);
          result.free();
        }
      }
      return result.address;
    } finally {
      queryPtr.free();
    }
  }

  @override
  String toString() {
    return 'QueryOperation(query: $query)';
  }
}
