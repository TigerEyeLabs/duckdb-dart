part of 'implementation.dart';

/// Mixin that provides cancellation support for database operations
mixin DatabaseOperationCancellation {
  /// Get the bindings instance
  Bindings get bindings;

  /// Get the database isolate instance
  ConnectionIsolate get isolate;

  /// Get the connection handle
  Pointer<duckdb_connection> get handle;

  /// Helper method to execute a database operation with cancellation support
  Future<T> runWithCancellation<T>({
    required DatabaseOperation operation,
    required Future<T> Function(Future<int> future) processResult,
    required String operationDescription,
    DuckDBCancellationToken? token,
  }) async {
    final (operationId, operationFuture) = isolate.executeWithId(operation);

    final result = await Future.any<T>([
      processResult(operationFuture),
      if (token != null)
        token.cancelled.then((_) {
          if (isolate.currentOperationId == operationId) {
            bindings.duckdb_interrupt(handle.value);
          }
          throw DuckDBCancelledException(operationDescription);
        }).then((value) => value as T),
    ]);
    return result;
  }
}
