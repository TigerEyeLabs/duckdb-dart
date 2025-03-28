import 'dart:async';

/// A token that can be used to cancel ongoing database operations asynchronously.
///
/// The DuckDBCancellationToken provides a Future-based mechanism to cancel
/// long-running database operations. This allows for both immediate checking of
/// cancellation state and waiting for cancellation events using Future APIs.
class DuckDBCancellationToken {
  /// Internal completer that manages the cancellation state
  final Completer<void> _completer = Completer<void>();

  /// Whether the token has been cancelled
  bool _isCancelled = false;

  /// Signals a cancellation request.
  ///
  /// Once cancelled, the token remains in the cancelled state and cannot be reset.
  /// This will complete the internal future, allowing any waiting operations
  /// to react to the cancellation.
  void cancel() {
    if (!_isCancelled) {
      _isCancelled = true;
      _completer.complete();
    }
  }

  /// Returns whether cancellation has been requested.
  bool get isCancelled => _isCancelled;

  /// Returns a Future that throws DuckDBCanceledException when cancellation is requested.
  ///
  /// This can be used directly with Future.any():
  /// ```dart
  /// await Future.any([
  ///   longRunningOperation(),
  ///   token.cancelled,
  /// ]);
  /// ```
  Future<void> get cancelled => _completer.future;
}
