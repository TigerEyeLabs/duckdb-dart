part of 'implementation.dart';

/// Contains the state of a connection needed for finalization.
///
/// This is extracted into separate object so that it can be used as a
/// finalization token. It will get disposed when the main database is no longer
/// reachable without being closed.
class _FinalizableLogicalType extends FinalizablePart {
  final Bindings _bindings;
  final Pointer<duckdb_logical_type> _handle;

  _FinalizableLogicalType(this._bindings, this._handle);

  @override
  void dispose() {
    _bindings.duckdb_destroy_logical_type(_handle);
    _handle.free();
  }
}

class LogicalType {
  final Bindings _bindings;
  var _isDisposed = false;

  final _FinalizableLogicalType _finalizable;
  final Finalizer<FinalizablePart> _finalizer = disposeFinalizer;

  Pointer<duckdb_logical_type> get handle => _finalizable._handle;

  LogicalType._(this._bindings, Pointer<duckdb_logical_type> handle)
      : _finalizable = _FinalizableLogicalType(_bindings, handle) {
    _finalizer.attach(this, _finalizable, detach: this);
  }

  factory LogicalType.withLogicalType(
    Pointer<duckdb_logical_type> logicalType,
  ) {
    return LogicalType._((duckdb as DuckDB).bindings, logicalType);
  }

  factory LogicalType.fromDatabaseType(DatabaseTypeNative type) {
    final logicalType = calloc<duckdb_logical_type>();
    logicalType.value =
        (duckdb as DuckDB).bindings.duckdb_create_logical_type(type.duckDbType);
    return LogicalType._((duckdb as DuckDB).bindings, logicalType);
  }

  DatabaseTypeNative get dataType => _dataType ??=
      DatabaseTypeNative.values[_bindings.duckdb_get_type_id(handle[0]).value];

  DatabaseTypeNative? _dataType;

  int bytesPerElement() {
    return Int32List.bytesPerElement;
  }

  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _finalizer.detach(this);
    _finalizable.dispose();
  }
}

extension DecimalLogicalType on LogicalType {
  ({int width, int scale, DatabaseType type}) decimalProperties() {
    return (
      width: _bindings.duckdb_decimal_width(handle.value),
      scale: _bindings.duckdb_decimal_scale(handle.value),
      type: DatabaseTypeNative
          .values[_bindings.duckdb_decimal_internal_type(handle.value).value],
    );
  }
}
