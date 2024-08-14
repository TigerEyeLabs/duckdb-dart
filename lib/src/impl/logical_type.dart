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
    return LogicalType._(duckdb.bindings, logicalType);
  }

  DatabaseType get dataType => _dataType ??=
      DatabaseType.values[_bindings.duckdb_get_type_id(handle[0])];

  DatabaseType? _dataType;

  int bytesPerElement() {
    return Int32List.bytesPerElement;
  }
}

extension DecimalLogicalType on LogicalType {
  ({int width, int scale, DatabaseType type}) decimalProperties() {
    return (
      width: _bindings.duckdb_decimal_width(handle.value),
      scale: _bindings.duckdb_decimal_scale(handle.value),
      type: DatabaseType
          .values[_bindings.duckdb_decimal_internal_type(handle.value)],
    );
  }
}