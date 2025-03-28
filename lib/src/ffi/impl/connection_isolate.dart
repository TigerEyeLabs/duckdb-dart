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

class ConnectionIsolate {
  static final _log = Logger('duckdb');

  // Port for receiving messages from the worker isolate
  final ReceivePort _receivePort = ReceivePort();

  // Port for receiving error messages from the worker isolate
  final ReceivePort _errorPort = ReceivePort();

  // Port for sending messages to the worker isolate
  late final SendPort _sendPort;

  // Maps operation IDs to their completion handlers
  final _responseCompleters = <int, Completer<int>>{};

  // Track the currently executing operation ID
  int? _currentOperationId;

  // Subscription for handling messages from the worker isolate
  late final StreamSubscription<dynamic> _subscription;

  // Subscription for handling error messages from the worker isolate
  late final StreamSubscription<dynamic> _errorSubscription;

  // Counter for generating unique operation IDs
  int _nextOperationId = 0;

  // Unique identifier for debugging this isolate instance
  String _debugId = const Uuid().v4().substring(0, 8);

  // Getter for currently executing operation ID
  int? get currentOperationId => _currentOperationId;

  ConnectionIsolate._();

  static Future<ConnectionIsolate> create({String? id}) async {
    final isolate = ConnectionIsolate._();
    // Append the optional id to the debug ID if provided
    if (id != null) {
      isolate._debugId = '${isolate._debugId}-$id';
    }
    _log.fine(
      'Creating new isolate: ${isolate._debugId}. Current isolates: ${_IsolateRegistry.instance.getActiveIsolatesInfo()}',
    );
    _IsolateRegistry.instance.register(isolate._debugId);

    try {
      await isolate._initialize();
      return isolate;
    } catch (e, st) {
      _log.severe(
        'Failed to create isolate ${isolate._debugId}. Active isolates: ${_IsolateRegistry.instance.getActiveIsolatesInfo()}',
        e,
        st,
      );
      _IsolateRegistry.instance.unregister(isolate._debugId);
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
        if (message.length == 2 &&
            message[0] is String &&
            message[1] is StackTrace) {
          // Error message
          _log.severe('Error in isolate:', message[0], message[1]);
        } else if (message.length == 1 && message[0] is int) {
          // Exit message
          _log.fine('Isolate exit code: ${message[0]}');
        }
      }
    });

    _log.fine('Starting isolate DuckDB-$_debugId');
    await Isolate.spawn(
      _isolateFunction,
      (_receivePort.sendPort, _debugId),
      debugName: 'DuckDB-$_debugId',
      errorsAreFatal: true,
      onError: _errorPort.sendPort,
      onExit: _errorPort.sendPort,
    );

    _sendPort = await sendPortCompleter.future;
    _log.fine('Received SendPort from isolate');

    // Add a small delay to ensure setup is complete
    await Future.delayed(const Duration(milliseconds: 100));

    // Verify the isolate is still active
    if (!_IsolateRegistry.instance.isActive(_debugId)) {
      throw StateError('Isolate became inactive during initialization');
    }
  }

  void _handleResponse(Object? message) {
    _log.fine('Received message: ${message.runtimeType}');

    // Handle error and exit messages
    if (message is List) {
      if (message.length == 2 &&
          message[0] is String &&
          message[1] is StackTrace) {
        // Error message
        _log.severe('Error in isolate:', message[0], message[1]);
      } else if (message.length == 1 && message[0] is int) {
        // Exit message
        _log.fine('Isolate exit code: ${message[0]}');
      }
      return;
    }

    if (message is _IsolateOperationStart) {
      _currentOperationId = message.id;
      _log.fine('Operation ${message.id} started');
    } else if (message is _IsolateResponse) {
      _log.fine('Handling response for ${message.id}');
      _currentOperationId = null;
      final completer = _responseCompleters.remove(message.id);
      if (completer != null) {
        if (message.error != null) {
          completer.completeError(message.error!);
        } else {
          completer.complete(message.result);
        }
      } else {
        _log.warning('No completer found for response ${message.id}');
      }
    } else if (message is SendPort) {
      _log.fine('Received SendPort from isolate');
    } else if (message is _IsolateShutdown) {
      _log.warning('Received unexpected shutdown message');
      // Don't handle shutdown messages in _handleResponse
      return;
    } else {
      _log.warning('Received unknown message type: ${message.runtimeType}');
    }
  }

  static Future<void> _isolateFunction((SendPort, String) params) async {
    final (sendPort, debugId) = params;
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

    // Listen for messages
    receivePort.listen((message) {
      log.fine('[Isolate:$debugId] Received message: ${message.runtimeType}');

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

      if (message is _IsolateShutdown) {
        log.fine('[Isolate:$debugId] Received shutdown request');
        shutdownCompleter.complete();
        return;
      }

      if (message is _IsolateRequest) {
        log.fine('[Isolate:$debugId] Received request ${message.id}');

        // Send back that we're starting this operation
        sendPort.send(_IsolateOperationStart(message.id));

        // Execute the operation
        message.operation.execute().then((result) {
          log.fine(
            '[Isolate:$debugId] Completed request ${message.id} with result: $result',
          );
          sendPort.send(_IsolateResponse(message.id, result: result));
        }).catchError((e, st) {
          log.severe(
            '[Isolate:$debugId] Error in request ${message.id}',
            e,
            st,
          );
          sendPort.send(_IsolateResponse(message.id, error: e));
        });
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
    receivePort.close();
    log.fine('[Isolate:$debugId] ReceivePort closed');

    // Kill the isolate after cleanup
    Isolate.current.kill(priority: Isolate.immediate);
  }

  Future<int> execute(DatabaseOperation operation) async {
    if (!_IsolateRegistry.instance.isActive(_debugId)) {
      throw StateError('Isolate is disposed or shutting down');
    }

    final id = _nextOperationId++;
    final completer = Completer<int>();
    _responseCompleters[id] = completer;

    _sendPort.send(_IsolateRequest(id, operation));

    return completer.future;
  }

  /// Executes an operation and returns both the operation ID and future result
  (int operationId, Future<int> future) executeWithId(
    DatabaseOperation operation,
  ) {
    if (!_IsolateRegistry.instance.isActive(_debugId)) {
      throw StateError('Isolate is disposed or shutting down');
    }

    final id = _nextOperationId++;
    final completer = Completer<int>();
    _responseCompleters[id] = completer;

    _sendPort.send(_IsolateRequest(id, operation));

    return (id, completer.future);
  }

  void _clearPendingRequests() {
    final pendingCompleters =
        Map<int, Completer<int>>.from(_responseCompleters);
    for (final entry in pendingCompleters.entries) {
      _log.fine('Clearing request ${entry.key}');
      entry.value.completeError(
        StateError('Connection is being disposed, operation interrupted'),
      );
      _responseCompleters.remove(entry.key);
    }
    _nextOperationId = 0;
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

    // Mark as shutting down first to prevent new requests
    _IsolateRegistry.instance.markShuttingDown(_debugId);
    _sendPort.send(const _IsolateShutdown());

    try {
      // Wait for current operation if any
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
      // Now clear any remaining requests
      _clearPendingRequests();

      await Future.wait([
        _subscription.cancel(),
        _errorSubscription.cancel(),
      ]);

      _responseCompleters.clear();
      _IsolateRegistry.instance.unregister(_debugId);
    }
  }
}

/// Base class for database operations that can be executed in a [ConnectionIsolate].
@immutable
abstract class DatabaseOperation {
  final int connectionPointer;

  const DatabaseOperation({
    required this.connectionPointer,
  });

  Future<int> execute();
}

/// Isolate Messages

class _IsolateRequest {
  final int id;
  final DatabaseOperation operation;

  _IsolateRequest(this.id, this.operation);
}

class _IsolateResponse {
  final int id;
  final int? result;
  final Object? error;

  _IsolateResponse(this.id, {this.result, this.error});
}

class _IsolateOperationStart {
  final int id;

  _IsolateOperationStart(this.id);
}

class _IsolateShutdown {
  const _IsolateShutdown();
}
