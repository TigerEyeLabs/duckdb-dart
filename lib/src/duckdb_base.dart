import 'package:dart_duckdb/src/api/connection.dart';
import 'package:dart_duckdb/src/api/database.dart';
import 'package:dart_duckdb/src/api/duckdb.dart';

/// Exists to satisfy the linter during static analysis.
class DuckDBBase implements DuckDB {
  // Constructor
  DuckDBBase._internal();

  @override
  dynamic get bindings => null;

  @override
  Future<Database> open(String filename, {Map<String, String>? settings}) {
    throw UnimplementedError('open is not implemented for this platform.');
  }

  @override
  Future<Connection> connect(Database database, {String? id}) {
    throw UnimplementedError('connect is not implemented for this platform.');
  }

  @override
  Future<Connection> connectWithTransferred(
    TransferableDatabase transferableDb, {
    String? id,
  }) {
    throw UnimplementedError(
      'connectWithTransferred is not implemented for this platform.',
    );
  }

  @override
  String get version =>
      throw UnimplementedError('version is not implemented for this platform.');
}

/// Default implementation of `duckdb` getter
DuckDB get duckdb =>
    throw UnimplementedError('duckdb is not implemented for this platform.');
