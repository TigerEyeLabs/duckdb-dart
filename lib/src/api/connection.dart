import 'package:dart_duckdb/src/api/appender.dart';
import 'package:dart_duckdb/src/api/cancellation_token.dart';
import 'package:dart_duckdb/src/api/prepared_statement.dart';
import 'package:dart_duckdb/src/api/result_set.dart';

/// A DuckDB connection implemented
abstract class Connection {
  /// The native DuckDB connection handle pointer
  dynamic get handle;

  /// The id of the connection
  String? get id;

  /// Executes a query and returns the result set
  /// Can be cancelled via token
  Future<ResultSet> query(String query, {DuckDBCancellationToken? token});

  /// Executes a query without returning results
  /// Can be cancelled,but not interrupted via token
  Future<void> execute(String query, {DuckDBCancellationToken? token});

  /// Creates a prepared statement from a query
  /// Can be cancelled,but not interrupted via token
  Future<PreparedStatement> prepare(String query);

  /// Creates an appender for inserting data into a table
  Future<Appender> append(String table, String? schema);

  /// Gets the ordered column names for a table
  Future<Iterable<String>> getColumnOrder(String table);

  /// Interrupts the currently running operation
  Future<void> interrupt();

  /// Closes the connection and frees resources
  Future<void> dispose();
}
