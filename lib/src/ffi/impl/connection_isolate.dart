part of 'implementation.dart';

/// Registry for managing active isolates.
/// This is not thread-safe, do not use in the isolate function.
class _IsolateRegistry {
  static final instance = _IsolateRegistry._();
  final _activeIsolates = <String>{};
  final _shuttingDown = <String>{};

  _IsolateRegistry._();

  void register(String id) {
    assert(!_activeIsolates.contains(id));
    _activeIsolates.add(id);
  }

  void markShuttingDown(String id) {
    if (_activeIsolates.contains(id)) {
      _shuttingDown.add(id);
    }
  }

  void unregister(String id) {
    _activeIsolates.remove(id);
    _shuttingDown.remove(id);
  }

  bool isActive(String id) =>
      _activeIsolates.contains(id) && !_shuttingDown.contains(id);

  // Add method to get active isolates info
  String getActiveIsolatesInfo() {
    final active = _activeIsolates.difference(_shuttingDown);
    final shuttingDown = _shuttingDown.intersection(_activeIsolates);
    return 'Active: ${active.join(', ')}, Shutting down: ${shuttingDown.join(', ')}';
  }
}

/// Helper class to hold a pending operation along with its ID and completer.
class _PendingOperation {
  final String id;
  final DatabaseOperation operation;
  final Completer<int> completer;

  _PendingOperation(this.id, this.operation, this.completer);
}

class ConnectionIsolate {
  static final _log = Logger('duckdb');
  static final _uuid = Uuid(goptions: GlobalOptions(MathRNG()));

  // Port for receiving messages from the worker isolate
  final ReceivePort _receivePort = ReceivePort();

  // Port for receiving error messages from the worker isolate
  final ReceivePort _errorPort = ReceivePort();

  // Port for sending messages to the worker isolate
  late final SendPort _sendPort;

  // Queue for pending operations in the main isolate.
  final Queue<_PendingOperation> _pendingOperations =
      Queue<_PendingOperation>();

  // Track the currently executing operation ID (if any).
  String? _currentOperationId;

  // Track the last cancelled operation ID
  String? _lastCancelledId;

  // Maps operation IDs to their completion handlers
  final _responseCompleters = <String, Completer<int>>{};

  // Subscriptions for receiving messages
  late final StreamSubscription<dynamic> _subscription;
  late final StreamSubscription<dynamic> _errorSubscription;

  // Unique identifier for debugging this isolate instance
  final String _debugId;

  // Getter for currently executing operation ID
  String? get currentOperationId => _currentOperationId;

  /// Generates a new unique operation ID.
  String _nextOperationId() => _uuid.v4().substring(0, 8);

  ConnectionIsolate._(this._debugId);

  /// Factory method to create a new isolate.
  ///
  /// The [id] parameter is optional and can be used to provide a custom identifier
  /// for debugging purposes.
  static Future<ConnectionIsolate> create({String? id}) async {
    final debugId = '${_uuid.v4().substring(0, 8)}${id != null ? '-$id' : ''}';
    final isolate = ConnectionIsolate._(debugId);
    _log.fine(
      'Creating new isolate: $debugId. Current isolates: ${_IsolateRegistry.instance.getActiveIsolatesInfo()}',
    );
    _IsolateRegistry.instance.register(debugId);

    try {
      await isolate._initialize();
      return isolate;
    } catch (e, st) {
      _log.severe(
        'Failed to create isolate $debugId. Active isolates: ${_IsolateRegistry.instance.getActiveIsolatesInfo()}',
        e,
        st,
      );
      _IsolateRegistry.instance.unregister(debugId);
      rethrow;
    }
  }

  Future<void> _initialize() async {
    final sendPortCompleter = Completer<SendPort>();

    _subscription = _receivePort.listen((message) {
      if (!sendPortCompleter.isCompleted && message is SendPort) {
        sendPortCompleter.complete(message);
        return;
      }
      _handleResponse(message);
    });

    // Handle error messages
    _errorSubscription = _errorPort.listen((message) {
      if (message is List) {
        final (error, stackTrace) = switch (message) {
          [String e, StackTrace st] => (e, st),
          [int code] when code != 0 => (
              'Isolate terminated with exit code: $code',
              null
            ),
          _ => (null, null),
        };

        if (error != null) {
          if (stackTrace != null) {
            _log.severe('Isolate crashed:', error, stackTrace);
          } else {
            _log.fine(error);
          }

          _clearPendingRequests();
          if (_currentOperationId != null) {
            final completer = _responseCompleters.remove(_currentOperationId);
            completer?.completeError(StateError(error), stackTrace);
            _currentOperationId = null;
          }
        }
      }
    });

    _log.fine('Starting isolate DuckDB-$_debugId');
    await Isolate.spawn(
      _isolateFunction,
      (_receivePort.sendPort, _errorPort.sendPort, _debugId),
      debugName: 'DuckDB-$_debugId',
      errorsAreFatal: true,
      onError: _errorPort.sendPort,
      onExit: _errorPort.sendPort,
    );

    _sendPort = await sendPortCompleter.future;
    _log.fine('Received SendPort from isolate');

    if (!_IsolateRegistry.instance.isActive(_debugId)) {
      throw StateError('Isolate became inactive during initialization');
    }
  }

  void _handleResponse(Object? message) {
    _log.fine('Received message: ${message.runtimeType}');

    switch (message) {
      case _IsolateOperationStart(:final id):
        _currentOperationId = id;
        _log.fine('Operation $id started');
      case _IsolateResponse(:final id, :final error, :final result):
        _log.fine('Handling response for $id');
        _currentOperationId = null;

        // Complete current operation
        final completer = _responseCompleters.remove(id);
        if (completer != null) {
          if (error != null) {
            completer.completeError(error);
          } else if (id == _lastCancelledId) {
            /// If the operation was cancelled while being sent to the connection
            /// isolate, we need to complete the operation with a cancelled exception.
            completer.completeError(
              DuckDBCancelledException('Operation was cancelled'),
            );
          } else {
            completer.complete(result);
          }
        } else {
          _log.warning('No completer found for response $id');
        }

        // Remove completed operation and send next if available
        if (_pendingOperations.isNotEmpty &&
            _pendingOperations.first.id == id) {
          _pendingOperations.removeFirst();
          if (_pendingOperations.isNotEmpty) {
            final nextOp = _pendingOperations.first;
            _sendPort.send(_IsolateRequest(nextOp.id, nextOp.operation));
          }
        }
      case SendPort():
        _log.fine('Received SendPort from isolate');
      case _IsolateShutdown():
        _log.fine('Received shutdown message');
      default:
        _log.warning('Received unknown message type: ${message?.runtimeType}');
    }
  }

  static Future<void> _isolateFunction(
    (SendPort, SendPort, String) params,
  ) async {
    final (sendPort, errorPort, debugId) = params;
    final receivePort = ReceivePort();
    final log = Logger('duckdb');

    // Configure logging for the isolate
    hierarchicalLoggingEnabled = true;

    log.fine('[Isolate:$debugId] Starting...');

    // Send our SendPort back to the main isolate
    sendPort.send(receivePort.sendPort);
    log.fine('[Isolate:$debugId] Sent SendPort to main isolate');

    // Create a completer to handle shutdown
    final shutdownCompleter = Completer<void>();

    // Create a stream controller for message handling
    final messageController = StreamController<dynamic>();
    final messageStream = messageController.stream;

    // Listen for data messages and add them to the stream
    receivePort.listen((message) {
      messageController.add(message);
    });

    // Process messages from the stream
    messageStream.listen((message) async {
      log.fine('[Isolate:$debugId] Processing message: ${message.runtimeType}');

      // Handle error and exit messages
      if (message is List) {
        if (message.length == 2 &&
            message[0] is String &&
            message[1] is StackTrace) {
          // Error message
          log.severe('Error in isolate:', message[0], message[1]);
        } else if (message.length == 1 && message[0] is int) {
          // Exit message
          log.fine('Isolate exit code: ${message[0]}');
        }
        return;
      }

      if (message is _IsolateRequest) {
        log.fine('[Isolate:$debugId] Received request ${message.id}');

        // Send back that we're starting this operation
        sendPort.send(_IsolateOperationStart(message.id, message.operation));

        // Execute the operation
        try {
          final result = await message.operation.execute();
          log.fine(
            '[Isolate:$debugId] Completed request ${message.id} with result: $result',
          );
          sendPort.send(_IsolateResponse(message.id, result: result));
        } catch (e, st) {
          log.severe(
            '[Isolate:$debugId] Error in request ${message.id}',
            e,
            st,
          );

          sendPort.send(_IsolateResponse(message.id, error: e));
        }
      } else if (message is _IsolateShutdown) {
        log.fine('[Isolate:$debugId] Received shutdown request');
        shutdownCompleter.complete();
      } else if (message == null) {
        log.warning('[Isolate:$debugId] Received null message, ignoring');
      } else {
        log.warning(
          '[Isolate:$debugId] Received unknown message type: ${message.runtimeType}',
        );
      }
    });

    // Wait for shutdown
    await shutdownCompleter.future;

    // Cleanup
    await messageController.close();
    receivePort.close();
    log.fine('[Isolate:$debugId] ReceivePorts closed');

    // Kill the isolate after cleanup
    Isolate.current.kill(priority: Isolate.immediate);
  }

  /// Executes an operation and returns both the operation ID and future result.
  (String id, Future<int> result) execute(DatabaseOperation operation) {
    if (!_IsolateRegistry.instance.isActive(_debugId)) {
      throw StateError('Isolate is disposed or shutting down');
    }
    final id = _nextOperationId();
    final completer = Completer<int>();
    _responseCompleters[id] = completer;

    // Just add to pending queue - no immediate dispatch
    final pendingOp = _PendingOperation(id, operation, completer);
    _pendingOperations.add(pendingOp);

    // If this is the first operation (no current operation), start it
    if (_currentOperationId == null && _pendingOperations.length == 1) {
      final op = _pendingOperations.first;
      _sendPort.send(_IsolateRequest(op.id, op.operation));
    }

    return (id, completer.future);
  }

  void _clearPendingRequests() {
    // Clear pending operations from the queue.
    while (_pendingOperations.isNotEmpty) {
      final op = _pendingOperations.removeFirst();
      final completer = _responseCompleters.remove(op.id);
      completer?.completeError(
        StateError('Connection is being disposed, operation interrupted'),
      );
    }
    // Clear any remaining completers.
    final pendingCompleters = Map<String, Completer<int>>.from(
      _responseCompleters,
    );
    for (final entry in pendingCompleters.entries) {
      _log.fine('Clearing request ${entry.key}');
      entry.value.completeError(
        StateError('Connection is being disposed, operation interrupted'),
      );
      _responseCompleters.remove(entry.key);
    }
  }

  /// Cancel a pending operation if it's still in the queue.
  Future<void> cancelOperation(String operationId) async {
    if (!_IsolateRegistry.instance.isActive(_debugId)) {
      throw StateError('Isolate is disposed or shutting down');
    }

    _lastCancelledId = operationId;

    // Check if the operation is still pending.
    final pendingOp =
        _pendingOperations.where((op) => op.id == operationId).firstOrNull;
    if (pendingOp != null && _pendingOperations.last.id != operationId) {
      _pendingOperations.remove(pendingOp);
      final completer = _responseCompleters.remove(operationId);
      _log.fine(
        'Cancelled operation $operationId. Queue size: ${_pendingOperations.length}',
      );
      completer?.completeError(
        DuckDBCancelledException('Operation was cancelled'),
      );
    }
  }

  Future<void> dispose() async {
    if (!_IsolateRegistry.instance.isActive(_debugId)) {
      _log.fine(
        'Already disposed or shutting down. Active isolates: ${_IsolateRegistry.instance.getActiveIsolatesInfo()}',
      );
      return;
    }

    _log.fine(
      'Starting dispose... Active isolates: ${_IsolateRegistry.instance.getActiveIsolatesInfo()}',
    );

    _IsolateRegistry.instance.markShuttingDown(_debugId);
    _sendPort.send(const _IsolateShutdown());

    try {
      if (_currentOperationId != null) {
        final currentCompleter = _responseCompleters[_currentOperationId!];
        if (currentCompleter != null) {
          await currentCompleter.future;
        }
      }
      _log.fine(
        'Dispose completed. Remaining isolates: ${_IsolateRegistry.instance.getActiveIsolatesInfo()}',
      );
    } catch (e, st) {
      _log.severe(
        'Error during dispose. Active isolates: ${_IsolateRegistry.instance.getActiveIsolatesInfo()}',
        e,
        st,
      );
      rethrow;
    } finally {
      _clearPendingRequests();

      await Future.wait([_subscription.cancel(), _errorSubscription.cancel()]);

      _responseCompleters.clear();
      _IsolateRegistry.instance.unregister(_debugId);
    }
  }
}

/// Base class for database operations that can be executed in a [ConnectionIsolate].
@immutable
abstract class DatabaseOperation {
  final int connectionPointer;

  const DatabaseOperation({required this.connectionPointer});

  Future<int> execute();
}

/// Isolate Messages, these are sent between the main isolate and the worker isolate.

class _IsolateRequest {
  final String id;
  final DatabaseOperation operation;

  _IsolateRequest(this.id, this.operation);
}

class _IsolateResponse {
  final String id;
  final int? result;
  final Object? error;

  _IsolateResponse(this.id, {this.result, this.error});
}

class _IsolateOperationStart {
  final String id;
  final DatabaseOperation operation;

  _IsolateOperationStart(this.id, this.operation);
}

class _IsolateShutdown {
  const _IsolateShutdown();
}
