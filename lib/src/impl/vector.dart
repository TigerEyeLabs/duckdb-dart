part of 'implementation.dart';

class Vector<T> {
  final Bindings _bindings;
  final duckdb_vector handle;
  final int count;
  final LogicalType logicalType;
  final VectorTransformer<T?> _transformer;
  final Pointer _dataPtr;
  final Pointer<Uint64>? _validityMask;

  Vector(
    this._bindings,
    this.handle,
    this.count,
    this.logicalType,
  )   : _transformer = getTransformerForType<T?>(logicalType.dataType),
        _dataPtr = _bindings.duckdb_vector_get_data(handle),
        _validityMask =
            _bindings.duckdb_vector_get_validity(handle).isNullPointer
                ? null
                : Pointer<Uint64>.fromAddress(
                    _bindings.duckdb_vector_get_validity(handle).address,
                  );

  T? getValue(int index) {
    assert(index < count, "vector index out of bounds $index >= $count");
    if (_validityMask?.isElementNull(index) ?? false) return null;
    return _transformer(
      _bindings,
      _dataPtr,
      index,
      handle,
      logicalType,
    );
  }
}
