part of 'implementation.dart';

class DatabaseImpl implements Database, TransferableDatabase {
  final String filename;
  final Map<String, String>? settings;
  final bindings.AsyncDuckDB? _realDatabase;

  static JSPromise<JSAny?>? _initializationPromise;

  static Future<DatabaseImpl> open(
    Bindings library, {
    String dbname = ':memory:',
    Map<String, String>? settings,
  }) async {
    final db =
        bindings.duckdbWasm.asyncDuckDB.callAsConstructor<bindings.AsyncDuckDB>(
      library.logger,
      library.worker,
    );

    _initializationPromise ??= db.instantiate(
      library.bundle.mainModule.toString(),
      library.bundle.pthreadWorker.toString(),
    );
    await _initializationPromise!.toDart;

    final jsOptions = JSObject();
    var accessModeValue = duckDBAccessMode['AUTOMATIC']!;
    if (settings != null) {
      for (final entry in settings.entries) {
        if (entry.key == 'access_mode') {
          final mode = duckDBAccessMode[entry.value];
          if (mode != null) {
            accessModeValue = mode;
          }
        } else {
          jsOptions[entry.key] = entry.value.toJS;
        }
      }
    }

    final config = bindings.DuckDBConfig(
      path: dbname,
      accessMode: accessModeValue,
      useThreads: true,
      options: jsOptions,
    );

    // Open database
    await db.open(config).toDart;

    return DatabaseImpl._(
      filename: dbname,
      settings: settings,
      realDatabase: db,
    );
  }

  @override
  Future<void> registerFileBuffer(String name, Uint8List buffer) async {
    await _realDatabase!.registerFileBuffer(name, buffer.toJS).toDart;
  }

  /// Register a file URL for DuckDB to access
  @override
  Future<void> registerFileURL(
    String name,
    String url,
    DuckDBDataProtocol protocol,
    bool directIO,
  ) async {
    final protocolValue = duckDBDataProtocolValues[protocol] ??
        duckDBDataProtocolValues[DuckDBDataProtocol.browserFsaccess]!;
    await _realDatabase!
        .registerFileURL(name, url, protocolValue, directIO)
        .toDart;
  }

  /// Register a file handle for DuckDB to access
  @override
  Future<void> registerFileHandle(
    String name,
    dynamic handle,
    DuckDBDataProtocol protocol,
    bool directIO,
  ) async {
    final protocolValue = duckDBDataProtocolValues[protocol] ??
        duckDBDataProtocolValues[DuckDBDataProtocol.browserFsaccess]!;
    final jsHandle = handle != null ? (handle as JSAny) : null;
    await _realDatabase!
        .registerFileHandle(name, jsHandle, protocolValue, directIO)
        .toDart;
  }

  static Future<ConnectionImpl> connect(
    DatabaseImpl database,
    Bindings library, {
    String? id,
  }) async {
    final connection = await database._realDatabase!.connect().toDart;
    return ConnectionImpl(connection: connection, id: id);
  }

  DatabaseImpl._({
    required this.filename,
    required this.settings,
    required bindings.AsyncDuckDB? realDatabase,
  }) : _realDatabase = realDatabase;

  @override
  Future<void> dispose() async {}

  @override
  dynamic get handle => _realDatabase;

  @override
  TransferableDatabase get transferable {
    return this;
  }
}
