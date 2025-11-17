part of 'implementation.dart';

class ColumnImpl<T> extends Column<T> {
  /// result of a duckdb query/prepared statement.
  final ResultSetImpl _result;
  ResultSet get result => _result;

  /// index into the result set.
  final int _columnIndex;
  int get columnIndex => _columnIndex;

  ColumnImpl(this._result, this._columnIndex);

  @override
  T? operator [](int index) {
    if (index < 0 || index >= _result.rowCount) {
      throw RangeError('Row index out of range: $index');
    }

    final batches = _result._result.getBatchesList();
    if (batches.isEmpty) return null;

    // Find the correct batch and row index within that batch
    var currentRow = 0;
    for (final batch in batches) {
      if (batch == null) continue;

      if (index < currentRow + batch.numRows) {
        // This is the batch containing our row
        final relativeIndex = index - currentRow;
        final columnData =
            batch.data.children.toDart[_columnIndex]! as bindings.Data;
        return _result.decodeValue(columnData, relativeIndex) as T?;
      }
      currentRow += batch.numRows;
    }

    return null;
  }
}
