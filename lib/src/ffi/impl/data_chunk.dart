part of 'implementation.dart';

/// Contains the state of a data chunk needed for finalization.
///
/// This is extracted into separate object so that it can be used as a
/// finalization token. It will get disposed when the main database is no longer
/// reachable without being closed.
class _FinalizableDataChunk extends FinalizablePart {
  final Bindings _bindings;
  final Pointer<duckdb_data_chunk> _handle;
  final Map<int, Vector> vectorCache = {};

  _FinalizableDataChunk(this._bindings, this._handle);

  @override
  void dispose() {
    // vectorCache.clear();
    _bindings.duckdb_destroy_data_chunk(_handle);
    _handle.free();
  }
}

class DataChunkImpl {
  final Bindings _bindings;

  final _FinalizableDataChunk _finalizable;
  final Finalizer<FinalizablePart> _finalizer = disposeFinalizer;

  Pointer<duckdb_data_chunk> get handle => _finalizable._handle;

  bool _isClosed = false;

  /// Cache the fixed values to make lookups fast.
  int? _count;
  int? _columnCount;

  DataChunkImpl._(this._bindings, Pointer<duckdb_data_chunk> chunk)
      : _finalizable = _FinalizableDataChunk(_bindings, chunk) {
    _finalizer.attach(this, _finalizable, detach: this);
  }

  factory DataChunkImpl.withResult(ResultSet result, int index) {
    final bindings = (duckdb as DuckDB).bindings;

    final dataChunk = allocate<duckdb_data_chunk>();
    dataChunk.value = Pointer.fromAddress(
      bindings
          .duckdb_result_get_chunk(
            (result.handle as Pointer<duckdb_result>)[0],
            index,
          )
          .address,
    );
    return DataChunkImpl._(bindings, dataChunk);
  }

  /// Sets the data chunk to the specified index in the result set.
  void setIndex(ResultSet result, int index) {
    // Update the handle to point to the new chunk
    _bindings.duckdb_destroy_data_chunk(_finalizable._handle);
    _finalizable._handle.value = Pointer.fromAddress(
      (duckdb as DuckDB)
          .bindings
          .duckdb_result_get_chunk(
            (result.handle as Pointer<duckdb_result>)[0],
            index,
          )
          .address,
    );
  }

  T? vectorAtIndex<T>(
    int columnIndex,
    T Function(Vector<T>) body,
    LogicalType logicalType,
  ) {
    final chunk = handle.value;
    final vector = _finalizable.vectorCache.putIfAbsent(
      columnIndex,
      () => Vector<T>(
        _bindings,
        _bindings.duckdb_data_chunk_get_vector(chunk, columnIndex),
        count,
        logicalType,
      ),
    ) as Vector<T>;

    return body(vector);
  }

  /// The number of tuples in the chunk
  int get count =>
      _count ??= _bindings.duckdb_data_chunk_get_size(handle.value);

  /// The number of columns in the chunk
  int get columnCount => _columnCount ??=
      _bindings.duckdb_data_chunk_get_column_count(handle.value);

  void dispose() {
    if (_isClosed) return;

    _finalizer.detach(this);
    _isClosed = true;

    _finalizable.dispose();
  }
}
