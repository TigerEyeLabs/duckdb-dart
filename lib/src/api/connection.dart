import 'dart:ffi';

import 'package:dart_duckdb/src/api/appender.dart';
import 'package:dart_duckdb/src/api/prepared_statement.dart';
import 'package:dart_duckdb/src/api/result_set.dart';

/// An opened duckdb connection with `dart:ffi`.
abstract class Connection {
  /// The native database connection handle from duckdb.
  ///
  /// This returns a pointer towards the opaque duckdb structure as defined
  /// [here](https://duckdb.org/docs/api/c/api#duckdb_connect).
  Pointer<void> get handle;

  /// Perform a database query
  ResultSet query(String query);

  /// Executes a sql query ignoring the result
  void execute(String query);

  /// Prepare a sql query
  PreparedStatement prepare(String query);

  /// Create an appender for insertion into a table
  Appender append(String table, String? schema);

  /// Get the column names of the table named [table],
  /// ordered as they are defined in the table's schema.
  Iterable<String> getColumnOrder(String table);

  /// Interrupt running query
  void interrupt();

  /// Closes this database and releases associated resources.
  void dispose();
}
