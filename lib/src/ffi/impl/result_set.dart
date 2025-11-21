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

  /// https://duckdb.org/docs/api/c/data_chunk
  // Data chunks represent a horizontal slice of a table. They hold a number of vectors,
  // each of which can hold up to VECTOR_SIZE rows. The vector size can be obtained through
  // the duckdb_vector_size function and is configurable, but is usually set to 2048.
  var _currentChunkIndex = 0;
  DataChunkImpl? _currentChunk;
  final List<int> _chunkOffsets = [];
  final Map<int, int> _chunkOffsetToChunkIndex = HashMap();

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
  late final List<Column<Object?>?> _columnCache =
      List.filled(columnCount, null);

  /// The number of chunks in the result set
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
    return _columnNames ??= List<String>.generate(
      columnCount,
      (index) => _bindings.duckdb_column_name(handle, index).readString(),
      growable: false,
    );
  }

  @override
  List<int> get columnTypes {
    return _columnTypes ??= List<int>.generate(
      columnCount,
      (column) => _bindings.duckdb_column_type(handle, column).value,
      growable: false,
    );
  }

  /// Return the database type for a given column.
  @override
  DatabaseTypeNative columnDataType(int index) {
    return DatabaseTypeNative.values[columnTypes[index]];
  }

  ResultSetImpl._(this._bindings, Pointer<duckdb_result> handle)
      : _finalizable = _FinalizableResultSet(_bindings, handle) {
    _finalizer.attach(this, _finalizable, detach: this);

    // Initialize _logicalTypes with fixed size
    _logicalTypes =
        List<LogicalType?>.filled(columnCount, null, growable: false);
  }

  factory ResultSetImpl.withResult(Pointer<duckdb_result> result) {
    return ResultSetImpl._((duckdb as DuckDB).bindings, result);
  }

  /// Use a generator to mimic a row cursor.
  late final Iterator<List<Object?>> _cursor = (() sync* {
    for (var rowIndex = 0; rowIndex < rowCount; rowIndex++) {
      final row = List<Object?>.generate(
        columnCount,
        (columnIndex) => this[columnIndex][rowIndex],
        growable: false,
      );
      yield row;
    }
  })()
      .iterator;

  /// Fetch the next row of a query result set, returning a single sequence,
  /// or null when no more data is available.
  @override
  List<Object?>? fetchOne() => _cursor.moveNext() ? _cursor.current : null;

  @override
  List<List<Object?>> fetchAll({int? batchSize}) {
    final rows = <List<Object?>>[];

    // Use DuckDB's vector size as default batch size for optimal performance
    final chunkSize = batchSize ?? vectorSize;

    // Pre-fetch all column accessors
    final columns = List.generate(
      columnCount,
      (columnIndex) => this[columnIndex],
      growable: false,
    );

    // Process in batches
    for (var offset = 0; offset < rowCount; offset += chunkSize) {
      final currentBatchSize = min(chunkSize, rowCount - offset);

      for (var i = 0; i < currentBatchSize; i++) {
        final rowIndex = offset + i;
        final row = List<Object?>.filled(columnCount, null, growable: false);
        for (var colIndex = 0; colIndex < columnCount; colIndex++) {
          row[colIndex] = columns[colIndex][rowIndex];
        }
        rows.add(row);
      }
    }

    return rows;
  }

  @override
  Stream<List<Object?>> fetchAllStream({int? batchSize}) async* {
    // Use DuckDB's vector size as default batch size for optimal performance
    final chunkSize = batchSize ?? vectorSize;

    // Pre-fetch all column accessors
    final columns = List.generate(
      columnCount,
      (columnIndex) => this[columnIndex],
      growable: false,
    );

    // Process in batches
    for (var offset = 0; offset < rowCount; offset += chunkSize) {
      final currentBatchSize = min(chunkSize, rowCount - offset);

      for (var i = 0; i < currentBatchSize; i++) {
        final rowIndex = offset + i;
        final row = List<Object?>.filled(columnCount, null, growable: false);
        for (var colIndex = 0; colIndex < columnCount; colIndex++) {
          row[colIndex] = columns[colIndex][rowIndex];
        }
        yield row;
      }
    }
  }

  @override
  Future<void> dispose() async {
    if (_isClosed) return;

    _finalizer.detach(this);
    _finalizable.dispose();

    _isClosed = true;
  }

  /// Returns the logical type for a given column index.
  /// This includes information about aliases (e.g., JSON, user-defined types).
  LogicalType logicalType(int columnIndex) {
    final type = _logicalTypes[columnIndex];
    if (type != null) {
      return type;
    }

    // Allocate the logical type pointer only if not cached
    final logicalTypePointer = allocate<duckdb_logical_type>();
    logicalTypePointer.value = Pointer.fromAddress(
      (duckdb as DuckDB)
          .bindings
          .duckdb_column_logical_type(handle, columnIndex)
          .address,
    );

    // Create the LogicalType and cache it
    return _logicalTypes[columnIndex] =
        LogicalType.withLogicalType(logicalTypePointer);
  }

  LogicalType _logicalType(int columnIndex) => logicalType(columnIndex);

  T? Function(int) transformOrNull<T>(int columnIndex) {
    return transformer<T?>(columnIndex, (Vector<T?> vector, int elementIndex) {
      return vector.getValue(elementIndex);
    });
  }

  @override
  Column<dynamic> operator [](int index) {
    if (index >= columnCount) {
      throw IndexError.withLength(index, columnCount);
    }

    // Check if this column is JSON type (based on logical type alias)
    final logicalType = _logicalType(index);
    if (logicalType.isJson) {
      // JSON types are returned as VARCHAR from the C API, but we can parse them
      return _columnCache[index] ??= ColumnImpl<dynamic>(
        this,
        index,
        (rowIndex) {
          final jsonString = transformOrNull<String>(index)(rowIndex);
          if (jsonString == null) {
            return null;
          }
          try {
            return JsonValue(jsonDecode(jsonString));
          } catch (e) {
            return JsonValue(jsonString, isValid: false);
          }
        },
      );
    }

    return _columnCache[index] ??= switch (columnDataType(index)) {
      DatabaseTypeNative.boolean =>
        ColumnImpl<bool?>(this, index, transformOrNull<bool>(index)),
      DatabaseTypeNative.tinyInt ||
      DatabaseTypeNative.smallInt ||
      DatabaseTypeNative.integer ||
      DatabaseTypeNative.uTinyInt ||
      DatabaseTypeNative.uSmallInt ||
      DatabaseTypeNative.uInteger ||
      DatabaseTypeNative.bigInt =>
        ColumnImpl<int?>(this, index, transformOrNull<int>(index)),
      DatabaseTypeNative.uBigInt ||
      DatabaseTypeNative.hugeInt ||
      DatabaseTypeNative.uHugeInt =>
        ColumnImpl<BigInt?>(this, index, transformOrNull<BigInt>(index)),
      DatabaseTypeNative.float ||
      DatabaseTypeNative.double =>
        ColumnImpl<double?>(this, index, transformOrNull<double>(index)),
      DatabaseTypeNative.varchar ||
      DatabaseTypeNative.bitString =>
        ColumnImpl<String?>(this, index, transformOrNull<String>(index)),
      DatabaseTypeNative.timestamp ||
      DatabaseTypeNative.timestampS ||
      DatabaseTypeNative.timestampMS ||
      DatabaseTypeNative.timestampNS ||
      DatabaseTypeNative.timestampTz =>
        ColumnImpl<DateTime?>(this, index, transformOrNull<DateTime>(index)),
      DatabaseTypeNative.date =>
        ColumnImpl<Date?>(this, index, transformOrNull<Date>(index)),
      DatabaseTypeNative.time =>
        ColumnImpl<Time?>(this, index, transformOrNull<Time>(index)),
      DatabaseTypeNative.timeTz => ColumnImpl<TimeWithOffset?>(
          this,
          index,
          transformOrNull<TimeWithOffset>(index),
        ),
      DatabaseTypeNative.interval =>
        ColumnImpl<Interval?>(this, index, transformOrNull<Interval>(index)),
      DatabaseTypeNative.blob =>
        ColumnImpl<Uint8List?>(this, index, transformOrNull<Uint8List>(index)),
      DatabaseTypeNative.uuid =>
        ColumnImpl<UuidValue?>(this, index, transformOrNull<UuidValue>(index)),
      DatabaseTypeNative.list => ColumnImpl<List<Object?>?>(
          this,
          index,
          transformOrNull<List<Object?>>(index),
        ),
      DatabaseTypeNative.structure => ColumnImpl<Map<String, Object?>?>(
          this,
          index,
          transformOrNull<Map<String, Object?>>(index),
        ),
      DatabaseTypeNative.map => ColumnImpl<Map<Object, Object?>?>(
          this,
          index,
          transformOrNull<Map<Object, Object?>>(index),
        ),
      DatabaseTypeNative.decimal =>
        ColumnImpl<Decimal?>(this, index, transformOrNull<Decimal>(index)),
      DatabaseTypeNative.enumeration => ColumnImpl<String?>(
          this,
          index,
          transformOrNull<String>(index),
        ),
      DatabaseTypeNative.array => ColumnImpl<List<Object?>?>(
          this,
          index,
          transformOrNull<List<Object?>>(index),
        ),
      _ => ColumnImpl<Object?>(this, index, transformOrNull<Object>(index))
    };
  }

  int get vectorSize => (duckdb.bindings! as Bindings).duckdb_vector_size();

  DataChunkImpl dataChunkByIndex(int chunkIndex) {
    if (_currentChunkIndex != chunkIndex) {
      _currentChunk?.dispose();
      _currentChunk = null;
      _currentChunkIndex = -1;
    }

    if (_currentChunk == null) {
      _currentChunk = DataChunkImpl.withResult(this, chunkIndex);
      _currentChunkIndex = chunkIndex;
    }

    return _currentChunk!;
  }

  TItem? Function(int) transformer<TItem>(
    int columnIndex,
    Function(Vector<TItem>, int) body,
  ) {
    return (int itemIndex) {
      final closestSmallerOffsetIndex = _findClosestSmallerOffset(itemIndex);
      var chunkIndex = closestSmallerOffsetIndex != -1
          ? _chunkOffsetToChunkIndex[_chunkOffsets[closestSmallerOffsetIndex]]!
          : 0;

      var chunkRowOffset = closestSmallerOffsetIndex != -1
          ? _chunkOffsets[closestSmallerOffsetIndex]
          : 0;

      while (chunkIndex < chunkCount) {
        final chunk = dataChunkByIndex(chunkIndex);
        final chunkSize = chunk.count;

        if (itemIndex < chunkRowOffset + chunkSize) {
          return chunk.vectorAtIndex<TItem>(
            columnIndex,
            (vector) => body(vector, itemIndex - chunkRowOffset),
            _logicalType(columnIndex),
          );
        } else {
          chunkIndex++;
          chunkRowOffset += chunkSize;

          if (!_chunkOffsetToChunkIndex.containsKey(chunkRowOffset)) {
            _chunkOffsets.add(chunkRowOffset);
            _chunkOffsetToChunkIndex[chunkRowOffset] = chunkIndex;
          }
        }
      }

      throw RangeError.range(
        itemIndex,
        0,
        chunkCount - 1,
        'index',
        'Index out of bounds',
      );
    };
  }

  var _lastFoundOffset = 0;
  int _findClosestSmallerOffset(int itemIndex) {
    // Early exit for common cases
    if (_chunkOffsets.isEmpty) return -1;
    if (itemIndex < _chunkOffsets[0]) return -1;
    if (itemIndex >= _chunkOffsets.last) return _chunkOffsets.length - 1;

    // Try last successful position first
    if (_lastFoundOffset < _chunkOffsets.length &&
        _chunkOffsets[_lastFoundOffset] <= itemIndex &&
        (_lastFoundOffset + 1 == _chunkOffsets.length ||
            _chunkOffsets[_lastFoundOffset + 1] > itemIndex)) {
      return _lastFoundOffset;
    }

    // Galloping search: Instead of checking every element or
    // doing a standard binary search, we first try to find the range where our value
    // might be by checking positions that grow exponentially (1, 2, 4, 8, 16...).
    // This is especially efficient for sequential access patterns as it quickly
    // finds the right neighborhood before switching to binary search.
    var i = 1;
    while (i < _chunkOffsets.length && _chunkOffsets[i] <= itemIndex) {
      i = i << 1;
    }

    // Binary search in the identified range
    var low = i >> 1;
    var high = min(i, _chunkOffsets.length - 1);

    while (low < high) {
      final mid = (low + high + 1) >>> 1;
      if (_chunkOffsets[mid] <= itemIndex) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }

    _lastFoundOffset = low;
    return low;
  }
}
