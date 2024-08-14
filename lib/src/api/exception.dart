class DuckDBException implements Exception {
  String message = 'unknown database error';

  DuckDBException(this.message);

  @override
  String toString() {
    return message;
  }
}
