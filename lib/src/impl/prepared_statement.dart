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

class PreparedStatementImpl extends PreparedStatement {
  final Bindings _bindings;

  final WeakReference<Connection> _connectionRef;
  final _FinalizablePreparedStatement _finalizable;
  final Finalizer<FinalizablePart> _finalizer = disposeFinalizer;
  bool _isClosed = false;

  /// Cache the fixed values to make lookups fast.
  int? _parameterCount;

  /// Map parameter names to parameter indices.
  final List _namedParameters;

  Pointer<duckdb_prepared_statement> get _handle => _finalizable._handle;

  PreparedStatementImpl._(
    this._bindings,
    Connection connection,
    Pointer<duckdb_prepared_statement> handle, [
    this._namedParameters = const [],
  ])  : _connectionRef = WeakReference(connection),
        _finalizable = _FinalizablePreparedStatement(_bindings, handle) {
    _finalizer.attach(this, _finalizable, detach: this);
  }

  factory PreparedStatementImpl.prepare(Connection connection, String query) {
    final bindings = duckdb.bindings;
    final outPrepare = allocate<duckdb_prepared_statement>();

    final namedParameters = query.getNamedParameters();

    if (bindings.duckdb_prepare(
          (connection.handle as Pointer<duckdb_connection>).value,
          query.toNativeUtf8() as Pointer<Char>,
          outPrepare,
        ) ==
        duckdb_state.DuckDBError) {
      final ddbError = bindings.duckdb_prepare_error(outPrepare.value);
      final msg = ddbError.cast<Utf8>().toDartString();
      bindings.duckdb_destroy_prepare(outPrepare);
      throw DuckDBException(msg);
    }

    return PreparedStatementImpl._(
      bindings,
      connection,
      outPrepare,
      namedParameters.map((name) => name.substring(1)).toList(),
    );
  }

  @override
  void dispose() {
    if (_isClosed) return;

    _finalizer.detach(this);
    _isClosed = true;

    _finalizable.dispose();
  }

  @override
  int get parameterCount =>
      _parameterCount ??= _bindings.duckdb_nparams(_handle.value);

  @override
  DatabaseType parameterType(int index) {
    return DatabaseType
        .values[_bindings.duckdb_param_type(_handle.value, index)];
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

  int _bindBigInt(int index, BigInt value) {
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

  int _bindString(int index, String value) {
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

  int _bindDateTime(int index, DateTime value) {
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

  int _bindDate(int index, Date value) {
    final date = allocate<duckdb_date>();
    date.ref.days = value.daysSinceEpoch;
    try {
      return _bindings.duckdb_bind_date(_handle.value, index, date.ref);
    } finally {
      date.free();
    }
  }

  int _bindTime(
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

  int _bindInterval(int index, Interval value) {
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

  int _bindDecimal(int index, Decimal value) {
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

  int _bindBlob(int index, Uint8List value) {
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

  int _bindScalar<T>(int index, T scalar) {
    final value = Value<T>(_bindings, scalar);
    try {
      return _bindings.duckdb_bind_value(_handle.value, index, value.handle);
    } finally {
      value.dispose();
    }
  }

  int _bindList<E>(int index, List<E> list) {
    final value = Value<List<E>>(_bindings, list);
    try {
      return _bindings.duckdb_bind_value(_handle.value, index, value.handle);
    } finally {
      value.dispose();
    }
  }

  int _bindStruct(
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
  ResultSet execute() {
    final result = allocate<duckdb_result>();
    try {
      if (duckdb_state.DuckDBError ==
          _bindings.duckdb_execute_prepared(_handle.value, result)) {
        final error = _bindings.duckdb_result_error(result).readString();
        result.free();
        throw DuckDBException(error);
      }
      return ResultSetImpl.withResult(result);
    } catch (e) {
      result.free();
      rethrow;
    }
  }

  @override
  CancelableOperation<ResultSet?> executeAsync({
    StreamController<double>? progressController,
    Duration? timeout,
  }) {
    final pendingResultHandle = allocate<duckdb_pending_result>();

    // Starts execution in the background if there are background
    // threads active e.g. threads (SET threads=x) where x > 1
    final result = _bindings.duckdb_pending_prepared(
      _handle.value,
      pendingResultHandle,
    );
    if (result == duckdb_state.DuckDBError) {
      _bindings.duckdb_destroy_pending(pendingResultHandle);
      throw DuckDBException(
        _bindings.duckdb_prepare_error(_handle.value).readString(),
      );
    }

    final pendingResult = PendingResultImpl._(_bindings, pendingResultHandle);
    var isCancelled = false;
    var percentage = -1.0;

    return CancelableOperation.fromFuture(
      Future(() async {
        while (!isCancelled) {
          await Future.delayed(Duration.zero);

          final state = pendingResult.executeTask();
          if (progressController != null) {
            final progress = _bindings.duckdb_query_progress(
              (_connectionRef.target!.handle as Pointer<duckdb_connection>)
                  .value,
            );
            if (progress.percentage != percentage) {
              percentage = progress.percentage;
              progressController.add(percentage);
            }
          }
          switch (state) {
            case PendingResultState.noTasksAvailable:
            case PendingResultState.notReady:
              continue;
            case PendingResultState.ready:
              final result = pendingResult.execute();
              progressController?.add(1.0);
              return result;
            case PendingResultState.error:
              throw DuckDBException(pendingResult.getPendingError());
          }
        }
        return null;
      }),
      onCancel: () {
        isCancelled = true;
        _connectionRef.target?.interrupt();
        progressController?.add(1.0);
        return Future.value(true);
      },
    );
  }
}
