part of 'implementation.dart';

/// Contains the state of a connection needed for finalization.
///
/// This is extracted into separate object so that it can be used as a
/// finalization token. It will get disposed when the main database is no longer
/// reachable without being closed.
class _FinalizablePreparedStatement extends FinalizablePart {
  final Bindings _bindings;
  final Pointer<duckdb_prepared_statement> _handle;

  _FinalizablePreparedStatement(this._bindings, this._handle);

  @override
  void dispose() {
    _bindings.duckdb_destroy_prepare(_handle);
    _handle.free();
  }
}

class PreparedStatementImpl extends PreparedStatement
    with DatabaseOperationCancellation {
  final Bindings _bindings;
  final WeakReference<ConnectionImpl> _connectionRef;
  final _FinalizablePreparedStatement _finalizable;
  final Finalizer<FinalizablePart> _finalizer = disposeFinalizer;
  bool _isClosed = false;

  /// Cache the fixed values to make lookups fast.
  int? _parameterCount;

  /// Map parameter names to parameter indices.
  final List _namedParameters;

  @override
  Bindings get bindings => _bindings;

  @override
  ConnectionIsolate get isolate => _connectionRef.target!._isolate;

  @override
  Pointer<duckdb_connection> get handle => _connectionRef.target!._handle;

  Pointer<duckdb_prepared_statement> get _handle => _finalizable._handle;

  PreparedStatementImpl._(
    this._bindings,
    ConnectionImpl connection,
    Pointer<duckdb_prepared_statement> handle, [
    this._namedParameters = const [],
  ])  : _connectionRef = WeakReference(connection),
        _finalizable = _FinalizablePreparedStatement(_bindings, handle) {
    _finalizer.attach(this, _finalizable, detach: this);
  }

  static Future<PreparedStatementImpl> prepare(
    ConnectionImpl connection,
    String query, {
    DuckDBCancellationToken? token,
  }) async {
    final bindings = (duckdb as DuckDB).bindings;

    final namedParameters = query.getNamedParameters();

    return connection.runWithCancellation(
      operation: PrepareOperation(
        connectionPointer: connection.handle.address,
        query: query,
      ),
      processResult: (future) async {
        final statementPointer = await future;
        return PreparedStatementImpl._(
          bindings,
          connection,
          Pointer<duckdb_prepared_statement>.fromAddress(statementPointer),
          namedParameters.map((name) => name.substring(1)).toList(),
        );
      },
      operationDescription: 'prepare statement',
      token: token,
    );
  }

  @override
  Future<void> dispose() async {
    if (_isClosed) return;

    _finalizer.detach(this);
    _isClosed = true;

    _finalizable.dispose();
  }

  @override
  int get parameterCount =>
      _parameterCount ??= _bindings.duckdb_nparams(_handle.value);

  @override
  DatabaseTypeNative parameterType(int index) {
    return DatabaseTypeNative
        .values[_bindings.duckdb_param_type(_handle.value, index).value];
  }

  @override
  void bind(Object? param, int index) {
    final preparedStatement = _handle.value;

    if (param == null) {
      _bindings.duckdb_bind_null(preparedStatement, index);
      return;
    }

    final bindResult = switch (param) {
      final bool value =>
        _bindings.duckdb_bind_boolean(preparedStatement, index, value),
      final int value => value.isNegative
          ? _bindings.duckdb_bind_int64(preparedStatement, index, value)
          : _bindings.duckdb_bind_uint64(preparedStatement, index, value),
      final double value =>
        _bindings.duckdb_bind_double(preparedStatement, index, value),
      final BigInt value => _bindBigInt(index, value),
      final String value => _bindString(index, value),
      final DateTime value => _bindDateTime(index, value),
      final Date value => _bindDate(index, value),
      final TimeWithOffset value => _bindScalar(index, value),
      final Time value => _bindTime(index, value),
      final Interval value => _bindInterval(index, value),
      final Decimal value => _bindDecimal(index, value),
      final Uint8List value => _bindBlob(index, value),
      final List<String> value => _bindList(index, value),
      final List<int> value => _bindList(index, value),
      final List<bool> value => _bindList(index, value),
      final List<double> value => _bindList(index, value),
      final List<DateTime> value => _bindList(index, value),
      final List<BigInt> value => _bindList(index, value),
      final List<Date> value => _bindList(index, value),
      final List<TimeWithOffset> value => _bindList(index, value),
      final List<Time> value => _bindList(index, value),
      final List<Interval> value => _bindList(index, value),
      final List<Uint8List> value => _bindList(index, value),
      final Map<String, Object> value => _bindStruct(index, value),
      _ => throw UnimplementedError(
          'Handling of parameter type ${param.runtimeType} not implemented.',
        ),
    };

    if (bindResult != duckdb_state.DuckDBSuccess) {
      final errorMessage = _bindings
          .duckdb_prepare_error(_handle.value)
          .cast<Utf8>()
          .toDartString();
      throw DuckDBException('Failed to bind value: $errorMessage');
    }
  }

  duckdb_state _bindBigInt(int index, BigInt value) {
    if (value <= hugeIntMax) {
      final hugeInt = value.toHugeInt();
      try {
        return _bindings.duckdb_bind_hugeint(
          _handle.value,
          index,
          hugeInt.ref,
        );
      } finally {
        hugeInt.free();
      }
    } else {
      final uHugeInt = value.toUHugeInt();
      try {
        return _bindings.duckdb_bind_uhugeint(
          _handle.value,
          index,
          uHugeInt.ref,
        );
      } finally {
        uHugeInt.free();
      }
    }
  }

  duckdb_state _bindString(int index, String value) {
    final bytes = utf8.encode(value);
    final nativeString = allocate<Uint8>(bytes.length);
    final nativeList = nativeString.asTypedList(bytes.length);
    nativeList.setAll(0, bytes);
    try {
      return _bindings.duckdb_bind_varchar_length(
        _handle.value,
        index,
        nativeString.cast<Char>(),
        bytes.length,
      );
    } finally {
      nativeString.free();
    }
  }

  duckdb_state _bindDateTime(int index, DateTime value) {
    final timestamp = value.toTimestamp();
    try {
      return _bindings.duckdb_bind_timestamp(
        _handle.value,
        index,
        timestamp.ref,
      );
    } finally {
      timestamp.free();
    }
  }

  duckdb_state _bindDate(int index, Date value) {
    final date = allocate<duckdb_date>();
    date.ref.days = value.daysSinceEpoch;
    try {
      return _bindings.duckdb_bind_date(_handle.value, index, date.ref);
    } finally {
      date.free();
    }
  }

  duckdb_state _bindTime(
    int index,
    Time value,
  ) {
    final time = allocate<duckdb_time>();
    time.ref.micros = value.toMicrosecondsSinceEpoch();
    try {
      return _bindings.duckdb_bind_time(_handle.value, index, time.ref);
    } finally {
      time.free();
    }
  }

  duckdb_state _bindInterval(int index, Interval value) {
    final interval = value.toDuckDbInterval();
    try {
      return _bindings.duckdb_bind_interval(
        _handle.value,
        index,
        interval.ref,
      );
    } finally {
      interval.free();
    }
  }

  duckdb_state _bindDecimal(int index, Decimal value) {
    final bigInt = value.number;
    final hugeInt = bigInt.toHugeInt();
    final decimal = allocate<duckdb_decimal>();
    decimal.ref.value = hugeInt.ref;
    decimal.ref.scale = value.scale;

    if (value == Decimal.zero) {
      decimal.ref.width = 0;
    } else {
      decimal.ref.width = (log(bigInt.toDouble().abs()) / ln10).floor();
    }

    try {
      return _bindings.duckdb_bind_decimal(
        _handle.value,
        index,
        decimal.ref,
      );
    } finally {
      decimal.free();
      hugeInt.free();
    }
  }

  duckdb_state _bindBlob(int index, Uint8List value) {
    final nativeBlob = allocate<Uint8>(value.length);
    nativeBlob.asTypedList(value.length).setAll(0, value);

    try {
      return _bindings.duckdb_bind_blob(
        _handle.value,
        index,
        nativeBlob.cast<Void>(),
        value.length,
      );
    } finally {
      nativeBlob.free();
    }
  }

  duckdb_state _bindScalar<T>(int index, T scalar) {
    final value = Value<T>(_bindings, scalar);
    try {
      return _bindings.duckdb_bind_value(_handle.value, index, value.handle);
    } finally {
      value.dispose();
    }
  }

  duckdb_state _bindList<E>(int index, List<E> list) {
    final value = Value<List<E>>(_bindings, list);
    try {
      return _bindings.duckdb_bind_value(_handle.value, index, value.handle);
    } finally {
      value.dispose();
    }
  }

  duckdb_state _bindStruct(
    int index,
    Map<String, Object> value,
  ) {
    final struct = Value<Map<String, Object>>(_bindings, value);
    try {
      return _bindings.duckdb_bind_value(
        _handle.value,
        index,
        struct.handle,
      );
    } finally {
      struct.dispose();
    }
  }

  @override
  void bindParams(List params) {
    for (var i = 0; i < params.length; i++) {
      bind(params[i], i + 1);
    }
  }

  @override
  void bindNamed(Object? param, String name) {
    bind(param, _namedParameters.indexOf(name) + 1);
  }

  @override
  void bindNamedParams(Map<String, Object?> params) {
    for (final entry in params.entries) {
      bindNamed(entry.value, entry.key);
    }
  }

  @override
  void clearBinding() {
    final bindResult = _bindings.duckdb_clear_bindings(_handle.value);
    if (bindResult != duckdb_state.DuckDBSuccess) {
      final errorMessage = _bindings
          .duckdb_prepare_error(_handle.value)
          .cast<Utf8>()
          .toDartString();
      throw DuckDBException('Failed to bind value: $errorMessage');
    }
  }

  @override
  Future<ResultSet> execute({DuckDBCancellationToken? token}) async {
    if (_isClosed) throw StateError('PreparedStatement is closed');

    final connection = _connectionRef.target;
    if (connection == null) throw StateError('Connection no longer exists');

    return runWithCancellation(
      operation: ExecutePreparedOperation(
        statementPointer: _handle.address,
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
      operationDescription: 'execute prepared statement',
      token: token,
    );
  }

  @override
  Future<ResultSet?> executePending({
    DuckDBCancellationToken? token,
  }) async {
    if (_isClosed) throw StateError('PreparedStatement is closed');

    final connection = _connectionRef.target;
    if (connection == null) throw StateError('Connection no longer exists');

    return runWithCancellation(
      operation: ExecutePreparedPendingOperation(
        statementPointer: _handle.address,
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
      operationDescription: 'execute pending prepared statement',
      token: token,
    );
  }
}

class PrepareOperation extends DatabaseOperation {
  final String query;

  const PrepareOperation({
    required super.connectionPointer,
    required this.query,
  });

  @override
  Future<int> execute() async {
    final bindings = (duckdb as DuckDB).bindings;
    final connection =
        Pointer<duckdb_connection>.fromAddress(connectionPointer);
    final outPrepare = allocate<duckdb_prepared_statement>();

    if (bindings.duckdb_prepare(
          connection.value,
          query.toNativeUtf8().cast<Char>(),
          outPrepare,
        ) ==
        duckdb_state.DuckDBError) {
      try {
        final errorString =
            bindings.duckdb_prepare_error(outPrepare.value).readString();
        throw DuckDBException(errorString);
      } finally {
        bindings.duckdb_destroy_prepare(outPrepare);
      }
    }

    return outPrepare.address;
  }
}

class ExecutePreparedPendingOperation extends DatabaseOperation {
  final int statementPointer;

  const ExecutePreparedPendingOperation({
    required this.statementPointer,
  }) : super(connectionPointer: 0);

  @override
  Future<int> execute() async {
    final bindings = (duckdb as DuckDB).bindings;
    final statement =
        Pointer<duckdb_prepared_statement>.fromAddress(statementPointer);
    final result = allocate<duckdb_result>();
    final pendingResultHandle = allocate<duckdb_pending_result>();

    try {
      if (bindings.duckdb_pending_prepared(
            statement.value,
            pendingResultHandle,
          ) ==
          duckdb_state.DuckDBError) {
        throw DuckDBException(
          bindings.duckdb_prepare_error(statement.value).readString(),
        );
      }

      // Execute pending result
      while (true) {
        final stateValue =
            bindings.duckdb_pending_execute_task(pendingResultHandle.value);
        final state = PendingResultState.values[stateValue.value];

        if (state == PendingResultState.ready) {
          if (bindings.duckdb_execute_pending(
                pendingResultHandle.value,
                result,
              ) ==
              duckdb_state.DuckDBError) {
            try {
              final errorString =
                  bindings.duckdb_result_error(result).readString();
              throw DuckDBException(errorString);
            } finally {
              bindings.duckdb_destroy_result(result);
            }
          }
          break;
        } else if (state == PendingResultState.error) {
          try {
            final errorString = bindings
                .duckdb_pending_error(pendingResultHandle.value)
                .readString();
            throw DuckDBException(errorString);
          } finally {
            bindings.duckdb_destroy_pending(pendingResultHandle);
          }
        }
      }

      return result.address;
    } catch (e) {
      result.free();
      pendingResultHandle.free();
      rethrow;
    }
  }
}

class ExecutePreparedOperation extends DatabaseOperation {
  final int statementPointer;

  const ExecutePreparedOperation({
    required this.statementPointer,
  }) : super(connectionPointer: 0);

  @override
  Future<int> execute() async {
    final bindings = (duckdb as DuckDB).bindings;
    final statement =
        Pointer<duckdb_prepared_statement>.fromAddress(statementPointer);
    final result = allocate<duckdb_result>();

    if (bindings.duckdb_execute_prepared(statement.value, result) ==
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
  }
}
