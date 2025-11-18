class DuckDBException implements Exception {
  final String message;
  final StackTrace? stackTrace;

  DuckDBException(
    this.message, {
    StackTrace? stackTrace,
  }) : stackTrace = stackTrace ?? StackTrace.current;

  @override
  String toString() {
    if (stackTrace != null) {
      return '$message\n$stackTrace';
    }
    return message;
  }
}

class DuckDBCancelledException extends DuckDBException {
  DuckDBCancelledException(
    super.message, {
    super.stackTrace,
  });

  @override
  String toString() {
    return 'DuckDB operation was cancelled: ${super.toString()}';
  }
}
