part of 'implementation.dart';

/// Contains the state of a pending result needed for finalization.
class _FinalizablePendingResult extends FinalizablePart {
  final Bindings _bindings;
  final Pointer<duckdb_pending_result> _handle;

  _FinalizablePendingResult(this._bindings, this._handle);

  @override
  void dispose() {
    _bindings.duckdb_destroy_pending(_handle);
    _handle.free();
  }
}

class PendingResultImpl {
  final _FinalizablePendingResult _finalizable;
  final Finalizer<FinalizablePart> _finalizer = disposeFinalizer;

  final Bindings _bindings;

  Pointer<duckdb_pending_result> get handle => _finalizable._handle;

  bool _isDestroyed = false;

  PendingResultImpl._(this._bindings, Pointer<duckdb_pending_result> handle)
      : _finalizable = _FinalizablePendingResult(_bindings, handle) {
    _finalizer.attach(this, _finalizable, detach: this);
  }

  void dispose() {
    if (_isDestroyed) return;

    _finalizer.detach(this);
    _finalizable.dispose();

    _isDestroyed = true;
  }

  /// Checks the state of the pending result, but will not progress the query forward.
  ///
  /// Returns:
  /// - [PendingResultState.ready]: The result is ready and [execute] can be called to obtain the result.
  /// - [PendingResultState.notReady]: The result is not ready yet. Call [executeTask] again.
  /// - [PendingResultState.error]: An error occurred during execution.
  ///   Use [getPendingError] to get the error message.
  /// - [PendingResultState.noTasksAvailable]: No more tasks are available for execution.
  PendingResultState checkState() {
    if (_isDestroyed) throw StateError('PendingResult is destroyed');
    final result = _bindings.duckdb_pending_execute_check_state(handle.value);
    return PendingResultState.fromInt(result.value);
  }

  /// Executes a single task within the query using `duckdb_pending_execute_task`, progressing the query's execution.
  /// This function should be called repeatedly (potentially in a loop) to ensure continuous progress on the query.
  /// It not only checks but also advances the execution state by processing pending tasks.
  /// If there are background threads active, they will concurrently process the query tasks in the background.
  /// However, if no background threads are active (i.e., SET threads=1), progress will only occur when a user thread calls this function.
  /// DuckDB manages the background threads automatically when the number of worker threads is set higher than one (`SET threads=X`).
  ///
  /// Returns:
  /// - [PendingResultState.ready]: The result is ready and [execute] can be called to obtain the result.
  /// - [PendingResultState.notReady]: The result is not ready yet. Call [executeTask] again.
  /// - [PendingResultState.error]: An error occurred during execution.
  ///   Use [getPendingError] to get the error message.
  /// - [PendingResultState.noTasksAvailable]: No more tasks are available for execution.
  PendingResultState executeTask() {
    if (_isDestroyed) throw StateError('PendingResult is destroyed');
    final result = _bindings.duckdb_pending_execute_task(handle.value);
    return PendingResultState.fromInt(result.value);
  }

  /// Fully executes the pending query result, returning the final query result.
  ///
  /// If [executeTask] has been called until [PendingResultState.ready] was returned,
  /// this will return quickly. Otherwise, all remaining tasks will be executed first.
  ///
  /// Throws a [DuckDBException] if an error occurs during execution.
  ResultSetImpl execute() {
    if (_isDestroyed) throw StateError('PendingResult is destroyed');

    final outResult = allocate<duckdb_result>();
    try {
      final result = _bindings.duckdb_execute_pending(handle.value, outResult);
      if (result == duckdb_state.DuckDBError) {
        throw DuckDBException(
          _bindings.duckdb_pending_error(handle.value).readString(),
        );
      }

      return ResultSetImpl._(_bindings, outResult);
    } catch (e) {
      outResult.free();
      rethrow;
    }
  }

  /// Returns the error message if the pending result is in an error state.
  String getPendingError() {
    if (_isDestroyed) throw StateError('PendingResult is destroyed');
    return _bindings.duckdb_pending_error(handle.value).readString();
  }
}

/// Represents the state of a pending result.
/// - DUCKDB_PENDING_RESULT_READY (ready), the ExecuteTask/CheckState function can be called to obtain the result.
/// - DUCKDB_PENDING_RESULT_NOT_READY (notReady), the ExecuteTask/CheckState function should be called again.
/// - DUCKDB_PENDING_ERROR (error), an error occurred during execution.
/// - DUCKDB_PENDING_NO_TASKS_AVAILABLE (noTasksAvailable), no meaningful work can be done by the current executor,
///   but tasks may become available in the future.
enum PendingResultState {
  ready,
  notReady,
  error,
  noTasksAvailable;

  /// Maps the FFI integer result to the corresponding enum value.
  static PendingResultState fromInt(int value) {
    switch (duckdb_pending_state.fromValue(value)) {
      case duckdb_pending_state.DUCKDB_PENDING_RESULT_READY:
        return PendingResultState.ready;
      case duckdb_pending_state.DUCKDB_PENDING_RESULT_NOT_READY:
        return PendingResultState.notReady;
      case duckdb_pending_state.DUCKDB_PENDING_ERROR:
        return PendingResultState.error;
      case duckdb_pending_state.DUCKDB_PENDING_NO_TASKS_AVAILABLE:
        return PendingResultState.noTasksAvailable;
    }
  }
}
