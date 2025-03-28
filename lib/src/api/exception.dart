class DuckDBException implements Exception {
  String message = 'unknown database error';

  DuckDBException(this.message);

  @override
  String toString() {
    return message;
  }
}

class DuckDBCancelledException implements Exception {
  /// The SQL query that was cancelled
  final String? sql;

  DuckDBCancelledException([this.sql]);

  @override
  String toString() {
    if (sql != null) {
      return 'Operation was cancelled: $sql';
    }
    return 'Operation was cancelled';
  }
}
