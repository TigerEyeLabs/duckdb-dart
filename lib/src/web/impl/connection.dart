part of 'implementation.dart';

class ConnectionImpl implements Connection {
  final bindings.Connection _connection;

  ConnectionImpl({
    required bindings.Connection connection,
    // ignore: avoid_unused_constructor_parameters
    String? id,
  }) : _connection = connection;

  @override
  String? get id => "unimplemented";

  @override
  dynamic get handle => _connection;

  Future<T> _handleJSError<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (e, stackTrace) {
      // ignore: invalid_runtime_check_with_js_interop_types
      if (e is JSObject) {
        final message = e.getProperty('message'.toJS)!.toString();
        throw DuckDBException(message, stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  @override
  Future<ResultSet> query(
    String query, {
    DuckDBCancellationToken? token,
  }) {
    return _handleJSError(() async {
      // Check if already cancelled before starting
      if (token != null && token.isCancelled) {
        throw DuckDBCancelledException('Operation cancelled');
      }

      // Get column type information first using DESCRIBE
      Set<int>? jsonColumnIndices;
      try {
        final describeTable = await _connection.query('DESCRIBE $query').toDart;
        final describeResult = ResultSetImpl(describeTable);
        final typeInfo = describeResult.fetchAll();

        jsonColumnIndices = <int>{};
        for (var i = 0; i < typeInfo.length; i++) {
          final row = typeInfo[i];
          // row[0] is column_name, row[1] is column_type
          if (row.length >= 2 && row[1]?.toString().toUpperCase() == 'JSON') {
            jsonColumnIndices.add(i);
          }
        }
      } catch (_) {
        // If DESCRIBE fails, fall back to heuristic detection
        jsonColumnIndices = null;
      }

      // Race between query execution and cancellation
      return Future.any<ResultSet>([
        // The actual query with type information
        _connection.query(query).toDart.then(
              (table) =>
                  ResultSetImpl(table, jsonColumnIndices: jsonColumnIndices),
            ),
        // Cancellation handler
        if (token != null)
          token.cancelled.then((_) {
            throw DuckDBCancelledException('Operation cancelled');
          }),
      ]);
    });
  }

  /// BLOCKED FROM STREAMING MODE BY LACK OF ENUM SUPPORT
  ///  https://github.com/duckdb/duckdb-wasm/issues/1548
  /*
    /// Send a query asynchronously and return a result set
    Future<ResultSet> send(
      String query, {
      bool allowStreamResult = false,
      DuckDBCancellationToken? token,
    }) async {
      return _handleJSError(() async {
        final reader = await _connection.send(query, allowStreamResult).toDart;

        // Read all batches from the stream using readAll
        final batches = await reader.readAll().toDart;

        // Create an Arrow Table from the batches using the Arrow Table constructor
        final table =
            bindings.arrowTable.callAsConstructor<bindings.ArrowTable>(batches);

        return ResultSetImpl(table);
      });
    }

    /// Cancel a query that was sent earlier
    Future<bool> _cancelSent() {
      return _handleJSError(() async {
        final result = await _connection.cancelSent().toDart;
        return result.toDart;
      });
    }
  */

  @override
  Future<void> execute(String query, {DuckDBCancellationToken? token}) {
    return _handleJSError(() async {
      // Check if already cancelled before starting
      if (token != null && token.isCancelled) {
        throw DuckDBCancelledException('Operation cancelled');
      }

      // Race between query execution and cancellation
      await Future.any<void>([
        // The actual query execution
        _connection.query(query).toDart,
        // Cancellation handler
        if (token != null)
          token.cancelled.then((_) {
            throw DuckDBCancelledException('Operation cancelled');
          }),
      ]);
    });
  }

  /// Prepare a sql query
  @override
  Future<PreparedStatement> prepare(
    String query, {
    DuckDBCancellationToken? token,
  }) {
    return _handleJSError(() async {
      // Check if already cancelled before starting
      if (token != null && token.isCancelled) {
        throw DuckDBCancelledException('Operation cancelled');
      }

      // Race between prepare execution and cancellation
      return Future.any<PreparedStatement>([
        // The actual prepare
        _connection
            .prepare(query)
            .toDart
            .then((statement) => PreparedStatementImpl(statement: statement)),
        // Cancellation handler
        if (token != null)
          token.cancelled.then((_) {
            throw DuckDBCancelledException('Operation cancelled');
          }),
      ]);
    });
  }

  /// Create an appender for insertion into a table
  @override
  Future<Appender> append(String table, String? schema) {
    // appender not implemented for web
    throw UnimplementedError();
  }

  /// Get the column names of the table named [table],
  /// ordered as they are defined in the table's schema.
  @override
  Future<Iterable<String>> getColumnOrder(String table) async {
    final sql = """
      SELECT column_name
      FROM information_schema.columns
      WHERE table_name = '$table'
      ORDER BY ordinal_position;
    """;

    final resultSet = await query(sql);
    return resultSet
        .fetchAll()
        .map((row) => row[0]! as String)
        .toList(growable: false);
  }

  /// Interrupt running query
  @override
  Future<void> interrupt() {
    // TODO: implement interrupt
    throw UnimplementedError();
  }

  /// Closes this database and releases associated resources.
  @override
  Future<void> dispose() async {
    // TODO: implement dispose
  }
}
