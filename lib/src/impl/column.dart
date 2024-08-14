part of 'implementation.dart';

class ColumnImpl extends Column {
  /// result of a duckdb query/prepared statement.
  final ResultSet _result;
  ResultSet get result => _result;

  /// index into the result set.
  final int _columnIndex;
  int get columnIndex => _columnIndex;

  /// method to safely unwrap a duckdb type and return a dart type
  final dynamic Function(int) _itemAt;

  ColumnImpl(this._result, this._columnIndex, this._itemAt);

  @override
  dynamic operator [](int index) {
    return _itemAt(index);
  }
}
