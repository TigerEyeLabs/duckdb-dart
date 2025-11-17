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
    if (token != null && token.isCancelled) {
      throw DuckDBCancelledException('Operation cancelled');
    }

    final (operationId, operationFuture) = isolate.execute(operation);

    Future<T> cancellationHandler() async {
      await token!.cancelled;

      // Mark that we're cancelling before interrupting
      final wasActive = isolate.currentOperationId == operationId;

      if (wasActive) {
        // Operation is currently active in the isolate
        bindings.duckdb_interrupt(handle.value);
      } else {
        // Cancel the operation - the isolate will handle it if it hasn't started yet
        await isolate.cancelOperation(operationId);
      }

      // Let operationFuture's result/exception propagate
      await operationFuture;

      // If we get here, the operation completed normally but was cancelled
      throw DuckDBCancelledException('Operation cancelled');
    }

    final result = await Future.any<T>([
      processResult(operationFuture),
      if (token != null) cancellationHandler(),
    ]);

    return result;
  }
}
