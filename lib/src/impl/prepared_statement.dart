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
    Pointer<duckdb_prepared_statement> handle, [
    this._namedParameters = const [],
  ]) : _finalizable = _FinalizablePreparedStatement(_bindings, handle) {
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
  void bind(dynamic param, int index) {
    final preparedStatement = _handle.value;
    if (param == null) {
      _bindings.duckdb_bind_null(preparedStatement, index);
    } else if (param is int) {
      if (param.isNegative) {
        _bindings.duckdb_bind_int64(preparedStatement, index, param);
      } else {
        _bindings.duckdb_bind_uint64(preparedStatement, index, param);
      }
    } else if (param is double) {
      _bindings.duckdb_bind_double(preparedStatement, index, param);
    } else if (param is BigInt) {
      // Assert the value is within the valid hugeInt and uHugeInt range
      assert(
        param <= uHugeIntMax,
        'Prepared Value exceeds the maximum unsigned 128-bit integer.',
      );
      assert(
        param >= hugeIntMin,
        'Prepared Value is less than the minimum signed 128-bit integer.',
      );

      if (param <= hugeIntMax) {
        final hugeInt = param.toHugeInt();
        _bindings.duckdb_bind_hugeint(preparedStatement, index, hugeInt.ref);
        hugeInt.free();
      } else {
        final uHugeInt = param.toUHugeInt();
        _bindings.duckdb_bind_uhugeint(preparedStatement, index, uHugeInt.ref);
        uHugeInt.free();
      }
    } else if (param is bool) {
      _bindings.duckdb_bind_boolean(preparedStatement, index, param);
    } else if (param is String) {
      final list = const Utf8Codec().encode(param);
      final nativeString = list.listToNativeUtf8().cast<Char>();
      _bindings.duckdb_bind_varchar_length(
        preparedStatement,
        index,
        nativeString,
        list.length,
      );
      nativeString.free();
    } else if (param is DateTime) {
      final timestamp = param.toTimestamp();
      _bindings.duckdb_bind_timestamp(preparedStatement, index, timestamp.ref);
      timestamp.free();
    } else if (param is Date) {
      final date = allocate<duckdb_date>();
      date.ref.days = param.daysSinceEpoch;
      _bindings.duckdb_bind_date(preparedStatement, index, date.ref);
      date.free();
    } else if (param is Decimal) {
      final bigInt = param.number;
      final hugeInt = bigInt.toHugeInt();

      final decimal = allocate<duckdb_decimal>();
      decimal.ref.value = hugeInt.ref;

      /// number of digits after the decimal point
      decimal.ref.scale = param.scale;

      /// number of digits total - log(x) / log(10)
      if (param == Decimal.zero) {
        decimal.ref.width = 0;
      } else {
        decimal.ref.width = (log(bigInt.toDouble().abs()) / ln10).floor();
      }

      _bindings.duckdb_bind_decimal(preparedStatement, index, decimal.ref);
      decimal.free();
      hugeInt.free();
    } else if (param is Interval) {
      final interval = param.toDuckDbInterval();
      _bindings.duckdb_bind_interval(preparedStatement, index, interval.ref);
      interval.free();
    } else if (param is Time) {
      final time = allocate<duckdb_time>();
      time.ref.micros = param.toMicrosecondsSinceEpoch();
      _bindings.duckdb_bind_time(preparedStatement, index, time.ref);
      time.free();
    } else {
      throw UnimplementedError(
        'Handling of parameter type ${param.runtimeType} not implemented.',
      );
    }
  }

  @override
  void bindParams(List params) {
    for (var i = 0; i < params.length; i++) {
      bind(params[i], i + 1);
    }
  }

  @override
  void bindNamed(dynamic param, String name) {
    bind(param, _namedParameters.indexOf(name) + 1);
  }

  @override
  void bindNamedParams(Map<String, dynamic> params) {
    for (final entry in params.entries) {
      bindNamed(entry.value, entry.key);
    }
  }

  @override
  void clearBinding() {
    _bindings.duckdb_clear_bindings(_handle.value);
  }

  @override
  ResultSet execute() {
    final result = allocate<duckdb_result>();

    if (duckdb_state.DuckDBError ==
        _bindings.duckdb_execute_prepared(_handle.value, result)) {
      throw DuckDBException(_bindings.duckdb_result_error(result).readString());
    }

    return ResultSetImpl.withResult(result);
  }
}
