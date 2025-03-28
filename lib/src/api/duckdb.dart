import 'package:dart_duckdb/src/api/connection.dart';
import 'package:dart_duckdb/src/api/database.dart';

abstract class DuckDB {
  Object? get bindings;

  Future<Database> open(String filename, {Map<String, String>? settings});

  Future<Connection> connect(
    Database database, {
    String? id,
  });

  Future<Connection> connectWithTransferred(
    TransferableDatabase transferableDb, {
    String? id,
  });

  String get version;
}
