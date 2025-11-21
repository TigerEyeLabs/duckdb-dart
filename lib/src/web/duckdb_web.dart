import 'dart:async';

import 'package:dart_duckdb/src/api/connection.dart';
import 'package:dart_duckdb/src/api/database.dart';
import 'package:dart_duckdb/src/api/duckdb.dart' as api;
import 'package:dart_duckdb/src/web/duckdb_bindings.dart' show getDuckDBVersion;
import 'package:dart_duckdb/src/web/impl/implementation.dart';
import 'package:dart_duckdb/src/web/load_library.dart';

/// https://shell.duckdb.org/docs/index.html

class DuckDB extends api.DuckDB {
  static DuckDB? instance;
  static late Future<Bindings>? _initFuture;

  @override
  Object? get bindings => _bindings;
  Bindings? _bindings;

  DuckDB._internal() {
    unawaited(
      _initFuture = OpenWasmLibrary().initializeDuckDB().then((bindings) {
        _bindings = bindings;
        return bindings;
      }),
    );
  }

  Future<Bindings> _getBindings() async {
    if (_bindings != null) return _bindings!;
    return _initFuture!;
  }

  static void registerWith(dynamic registrar) {
    DuckDB.instance = duckdb as DuckDB?;
  }

  @override
  Future<Database> open(
    String filename, {
    Map<String, String>? settings,
  }) async {
    final bindings = await _getBindings();
    return DatabaseImpl.open(
      bindings,
      dbname: filename,
      settings: settings,
    );
  }

  @override
  Future<Connection> connect(Database database, {String? id}) async {
    final bindings = await _getBindings();
    return DatabaseImpl.connect(database as DatabaseImpl, bindings, id: id);
  }

  @override
  Future<Connection> connectWithTransferred(
    TransferableDatabase transferableDb, {
    String? id,
  }) async {
    return connect(transferableDb as Database, id: id);
  }

  @override
  String get version => getDuckDBVersion();
}

DuckDB? _duckDB;

api.DuckDB get duckdb {
  _duckDB ??= DuckDB._internal();
  return _duckDB!;
}
