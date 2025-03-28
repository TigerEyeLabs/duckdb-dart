part of 'implementation.dart';

/// Contains the state of an appender needed for finalization.
///
/// This is extracted into separate object so that it can be used as a
/// finalization token. It will get disposed when the main database is no longer
/// reachable without being closed.
class _FinalizableAppender extends FinalizablePart {
  final Bindings _bindings;
  final Pointer<duckdb_appender> _handle;

  _FinalizableAppender(this._bindings, this._handle);

  @override
  void dispose() {
    /// close, flush, free memory
    _bindings.duckdb_appender_destroy(_handle);
    _handle.free();
  }
}

class AppenderImpl extends Appender {
  final _FinalizableAppender _finalizable;
  final Finalizer<FinalizablePart> _finalizer = disposeFinalizer;

  final Bindings _bindings;

  @override
  Pointer<duckdb_appender> get handle => _finalizable._handle;

  bool _isClosed = false;

  AppenderImpl._(this._bindings, Pointer<duckdb_appender> handle)
      : _finalizable = _FinalizableAppender(_bindings, handle) {
    _finalizer.attach(this, _finalizable, detach: this);
  }

  factory AppenderImpl.withConnection(
    Connection connection,
    String table,
    String? schema,
  ) {
    final outAppender = allocate<duckdb_appender>();

    (duckdb as DuckDB).bindings.duckdb_appender_create(
          (connection.handle as Pointer<duckdb_connection>).value,
          (schema ?? "").toNativeUtf8() as Pointer<Char>,
          table.toNativeUtf8() as Pointer<Char>,
          outAppender,
        );
    return AppenderImpl._((duckdb as DuckDB).bindings, outAppender);
  }

  @override
  void append(dynamic value) {
    var status = duckdb_state.DuckDBError;

    final appender = handle.value;
    if (value == null) {
      status = _bindings.duckdb_append_null(appender);
    } else if (value is int) {
      if (value.isNegative) {
        status = _bindings.duckdb_append_int64(appender, value);
      } else {
        status = _bindings.duckdb_append_uint64(appender, value);
      }
    } else if (value is double) {
      status = _bindings.duckdb_append_double(appender, value);
    } else if (value is BigInt) {
      assert(
        value <= uHugeIntMax,
        'Appended Value exceeds the maximum unsigned 128-bit integer.',
      );
      assert(
        value >= hugeIntMin,
        'Appended Value is less than the minimum signed 128-bit integer.',
      );

      if (value <= hugeIntMax) {
        final hugeInt = value.toHugeInt();
        status = _bindings.duckdb_append_hugeint(appender, hugeInt.ref);
        hugeInt.free();
      } else {
        final uHugeInt = value.toUHugeInt();
        status = _bindings.duckdb_append_uhugeint(appender, uHugeInt.ref);
        uHugeInt.free();
      }
    } else if (value is bool) {
      status = _bindings.duckdb_append_bool(appender, value);
    } else if (value is String) {
      final nativeString = value.toNativeUtf8();
      status =
          _bindings.duckdb_append_varchar(appender, nativeString.cast<Char>());
      nativeString.free();
    } else if (value is Interval) {
      final interval = value.toDuckDbInterval();
      status = _bindings.duckdb_append_interval(appender, interval.ref);
      interval.free();
    } else if (value is DateTime) {
      final timestamp = value.toTimestamp();
      status = _bindings.duckdb_append_timestamp(appender, timestamp.ref);
      timestamp.free();
    } else if (value is Date) {
      final date = allocate<duckdb_date>();
      date.ref.days = value.daysSinceEpoch;
      status = _bindings.duckdb_append_date(appender, date.ref);
      date.free();
    } else if (value is Time) {
      final time = allocate<duckdb_time>();
      time.ref.micros = value.toMicrosecondsSinceEpoch();
      status = _bindings.duckdb_append_time(appender, time.ref);
      time.free();
    } else if (value is Uint8List) {
      // Copy the data into native memory
      final nativeBlob = calloc<Uint8>(value.length);
      final nativeBlobList = nativeBlob.asTypedList(value.length);
      nativeBlobList.setAll(0, value);

      // Cast to Pointer<Void> to match the expected parameter type
      final dataPtr = nativeBlob.cast<Void>();

      // Call the native function
      status = _bindings.duckdb_append_blob(
        appender,
        dataPtr,
        value.length,
      );

      calloc.free(nativeBlob);
    } else {
      throw UnimplementedError(
        'Type ${value.runtimeType} not supported by appender',
      );
    }

    if (status == duckdb_state.DuckDBError) {
      throw DuckDBException(
        _bindings.duckdb_appender_error(handle.value).readString(),
      );
    }
  }

  @override
  void endRow() {
    final status = _bindings.duckdb_appender_end_row(handle.value);
    if (status == duckdb_state.DuckDBError) {
      throw DuckDBException(
        _bindings.duckdb_appender_error(handle.value).readString(),
      );
    }
  }

  @override
  void flush() {
    final status = _bindings.duckdb_appender_flush(handle.value);
    if (status == duckdb_state.DuckDBError) {
      throw DuckDBException(
        _bindings.duckdb_appender_error(handle.value).readString(),
      );
    }
  }

  @override
  void dispose() {
    if (_isClosed) return;

    _finalizer.detach(this);
    _finalizable.dispose();

    _isClosed = true;
  }
}
