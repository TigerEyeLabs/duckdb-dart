import 'package:dart_duckdb/src/api/connection.dart';
import 'package:dart_duckdb/src/api/database.dart';

abstract class DuckDB {
  Database open(String filename, {Map<String, String>? settings});

  Connection connect(Database database);

  Connection connectWithTransferred(TransferableDatabase transferrableDb);

  String get version;
}
