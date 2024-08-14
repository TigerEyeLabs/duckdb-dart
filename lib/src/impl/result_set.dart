part of 'implementation.dart';

/// Contains the state of a connection needed for finalization.
///
/// This is extracted into separate object so that it can be used as a
/// finalization token. It will get disposed when the main database is no longer
/// reachable without being closed.
class _FinalizableResultSet extends FinalizablePart {
  final Bindings _bindings;
  final Pointer<duckdb_result> _handle;

  _FinalizableResultSet(this._bindings, this._handle);

  @override
  void dispose() {
    _bindings.duckdb_destroy_result(_handle);
    _handle.free();
  }
}

class ResultSetImpl extends ResultSet {
  final _FinalizableResultSet _finalizable;
  final Finalizer<FinalizablePart> _finalizer = disposeFinalizer;
  late final List<LogicalType?> _logicalTypes;

  final _chunkSizesMap = SplayTreeMap<int, int>();
  var _currentChunkIndex = 0;
  DataChunkImpl? _currentChunk;

  final Bindings _bindings;

  @override
  Pointer<duckdb_result> get handle => _finalizable._handle;

  bool _isClosed = false;

  /// Cache the fixed values to make lookups fast.
  int? _columnCount;
  int? _chunkCount;
  int? _rowCount;
  List<String>? _columnNames;
  List<int>? _columnTypes;

  /// The number of chunks in the result set
  @override
  int get chunkCount =>
      _chunkCount ??= _bindings.duckdb_result_chunk_count(handle.ref);

  /// The number of columns in the result set
  @override
  int get columnCount => _columnCount ??= _bindings.duckdb_column_count(handle);

  /// The total number of rows in the result set
  @override
  int get rowCount => _rowCount ??= _bindings.duckdb_row_count(handle);

  @override
  List<String> get columnNames {
    return _columnNames ??= () {
      final result = <String>[];
      for (var column = 0; column < columnCount; column++) {
        final name = _bindings.duckdb_column_name(handle, column);
        result.add(name.readString());
      }
      return result;
    }();
  }

  @override
  List<int> get columnTypes {
    return _columnTypes ??= () {
      final result = <int>[];
      for (var column = 0; column < columnCount; column++) {
        final type = _bindings.duckdb_column_type(handle, column);
        result.add(type);
      }

      return result;
    }();
  }

  /// Return the database type for a given column.
  @override
  DatabaseType columnDataType(int index) {
    return DatabaseType.values[columnTypes[index]];
  }

  ResultSetImpl._(this._bindings, Pointer<duckdb_result> handle)
      : _finalizable = _FinalizableResultSet(_bindings, handle) {
    _finalizer.attach(this, _finalizable, detach: this);

    // Filling with nulls, so there will be a null for each column until we have
    // cached the value for that column.
    _logicalTypes = List.filled(columnCount, null, growable: false);
  }

  factory ResultSetImpl.withResult(Pointer<duckdb_result> result) {
    return ResultSetImpl._(duckdb.bindings, result);
  }

  /// Use a generator to mimic a row cursor.
  late final Iterator<List> _cursor = (() sync* {
    final columns = <Column>[];
    for (var rowIndex = 0; rowIndex < rowCount; rowIndex++) {
      final row = [];
      for (var columnIndex = 0; columnIndex < columnCount; columnIndex++) {
        // While iterating on the first row in the results, add the columns so
        // we can quickly access them through the rest of the query.
        if (rowIndex == 0) {
          columns.add(this[columnIndex]);
        }
        row.add(columns[columnIndex][rowIndex]);
      }
      yield row;
    }
  })()
      .iterator;

  /// Fetch the next row of a query result set, returning a single sequence,
  /// or null when no more data is available.
  @override
  List? fetchOne() => _cursor.moveNext() ? _cursor.current : null;

  /// Fetch all (remaining) rows of a query result, returning them
  /// as a sequence of sequences (e.g. a list of lists). Return an
  /// empty list when no more data is available.
  @override
  List<List> fetchAll() {
    final remaining = <List>[];
    while (_cursor.moveNext()) {
      remaining.add(_cursor.current);
    }
    return remaining;
  }

  @override
  void dispose() {
    if (_isClosed) return;

    _finalizer.detach(this);
    _finalizable.dispose();

    _isClosed = true;
  }

  LogicalType _logicalType(int columnIndex) {
    var type = _logicalTypes[columnIndex];
    if (type == null) {
      final logicalType = allocate<duckdb_logical_type>();
      logicalType.value = Pointer.fromAddress(
        duckdb.bindings.duckdb_column_logical_type(handle, columnIndex).address,
      );
      type = LogicalType.withLogicalType(logicalType);
      _logicalTypes[columnIndex] = type;
    }
    return type;
  }

  @override
  Column operator [](int index) {
    if (index >= columnCount) {
      throw IndexError.withLength(index, columnCount);
    }

    return ColumnImpl(this, index, transformOrNull(index));
  }
}

extension Transformer on ResultSetImpl {
  Function(int) transformOrNull(int columnIndex) {
    return transformer(columnIndex, (Vector vector, int elementIndex) {
      if (vector.unwrapNull(elementIndex)) {
        return null;
      }

      return vector.unwrap(elementIndex);
    });
  }
}

extension DataExtraction on ResultSetImpl {
  int get vectorSize => duckdb.bindings.duckdb_vector_size();

  /// Used to cache chunks for responses.
  DataChunkImpl dataChunkByIndex(int chunkIndex) {
    // toss out the current chunk if requesting a different chunk.
    if (_currentChunkIndex != chunkIndex) {
      _currentChunk?.dispose();
      _currentChunk = null;
      _currentChunkIndex = -1;
    }

    // Check if the current chunk contains the itemIndex
    if (_currentChunk == null) {
      _currentChunk = DataChunkImpl.withResult(this, chunkIndex);
      _currentChunkIndex = chunkIndex;
    }

    return _currentChunk!;
  }

  dynamic Function(int) transformer(
    int columnIndex,
    Function(Vector, int) body,
  ) {
    return (int itemIndex) {
      /// Index of the current data chunk being processed.
      final closestSmallerOffset = _chunkSizesMap.lastKeyBefore(itemIndex);
      var chunkIndex = closestSmallerOffset != null
          ? _chunkSizesMap[closestSmallerOffset]!
          : 0;

      /// Accumulated row count from previously processed chunks.
      var chunkRowOffset = closestSmallerOffset ?? 0;

      while (chunkIndex < chunkCount) {
        final chunk = dataChunkByIndex(chunkIndex);
        final chunkSize = chunk.count;

        if (itemIndex < chunkRowOffset + chunkSize) {
          return chunk.vectorAtIndex(
            columnIndex,
            (vector) => body(vector, itemIndex - chunkRowOffset),
            logicalType: _logicalType(columnIndex),
          );
        } else {
          chunkIndex++;
          chunkRowOffset += chunkSize;

          /// Cache the known chunk sizes and indices as we learn them
          if (!_chunkSizesMap.containsKey(chunkRowOffset)) {
            _chunkSizesMap[chunkRowOffset] = chunkIndex;
          }
        }
      }

      throw StateError("requested item out of bounds");
    };
  }
}
