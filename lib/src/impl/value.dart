part of 'implementation.dart';

/// Contains the state of a value needed for finalization.
///
/// This is extracted into separate object so that it can be used as a
/// finalization token.
class _FinalizableValue extends FinalizablePart {
  final Bindings _bindings;
  final duckdb_value _handle;

  _FinalizableValue(this._bindings, this._handle);

  @override
  void dispose() {
    /// duckdb_destroy_value needs a Pointer<duckdb_value>
    final valuePointerPointer = allocate<duckdb_value>();
    valuePointerPointer.value = _handle;

    _bindings.duckdb_destroy_value(valuePointerPointer);

    valuePointerPointer.free();
  }
}

/// https://duckdb.org/docs/api/c/value
class Value<T> {
  final _FinalizableValue _finalizable;
  final Finalizer<FinalizablePart> _finalizer = disposeFinalizer;
  bool _disposed = false;

  duckdb_value get handle => _finalizable._handle;

  Value(Bindings bindings, T value)
      : _finalizable = _FinalizableValue(
          bindings,
          ValueFactory.getCreator<T>().createValue(bindings, value),
        ) {
    _finalizer.attach(this, _finalizable, detach: this);
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _finalizer.detach(this);
    _finalizable.dispose();
  }
}
