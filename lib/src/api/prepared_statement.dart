import 'dart:async';

import 'package:async/async.dart';
import 'package:dart_duckdb/src/api/database_type.dart';
import 'package:dart_duckdb/src/api/result_set.dart';

/// An object reperesenting a DuckDB prepared statement
///
/// A prepared statement is a parameterized query. The query is prepared with
/// question marks (`?`), dollar symbols (`$1`), or named parameers (`$VVV`)
/// where VVV is alphanumeric, indicating the parameters of the query. Values can then
/// be bound to these parameters, after which the prepared statement can be executed
/// using those parameters. A single query can be prepared once and executed many times.
/// see: https://duckdb.org/docs/api/python/dbapi#named-parameters
///
/// Prepared statements are useful to:
///
///   - Easily supply parameters to functions while avoiding string
///     concatenation/SQL injection attacks.
///   - Speed up queries that will be executed many times with different
///     parameters.
///
/// The following example creates a prepared statement that allows parameters
/// to be bound in two positions within a 'select' statement. The prepared
/// statement is finally executed by calling ``PreparedStatement/execute()``.
///
/// ```dart
///   Connection connection = ...
///   connection.execute("CREATE TABLE t1(col1 TEXT, col2 TEXT);");
///   PreparedStatement statement = PreparedStatementImpl.prepare(
///     connection,
///     "INSERT INTO t1 VALUES ($col1, $col2, $col3)",
///   );
///   statement.bindNamedParams({'col1': 'val1', 'col2': 'val2'});
///   statement.execute();
///   ResultSet result = connection.query("SELECT * FROM t1;");
/// ```
abstract class PreparedStatement {
  /// Returns the amount of parameters in this prepared statement.
  int get parameterCount;

  DatabaseType parameterType(int index);

  /// Binds a value at the specified parameter index
  ///
  /// Sets the value that will be used for the next call to ``execute()``.
  ///
  /// - Important: Prepared statement parameters use one-based indexing
  /// - Parameter value: the value to bind
  /// - Parameter index: the one-based parameter index
  /// - Throws: ``DuckDBException``
  ///   if there is a type-mismatch between the value being bound and the
  ///   underlying column type
  void bind(Object? param, int index);

  /// Binds an ordered list of values
  void bindParams(List params);

  /// Binds a named value
  void bindNamed(Object? param, String name);

  /// Binds a map of named values, where the key is the name
  void bindNamedParams(Map<String, Object?> params);

  /// Executes the prepared statement
  ///
  /// Issues the parameterized query to the database using the values previously
  /// bound via the bind methods
  ResultSet execute();

  /// Executes the prepared statement asynchronously, and receive progress updates
  ///
  /// Issues the parameterized query to the database using the values previously
  /// bound via the bind methods. Returns a CancelableOperation that can be used
  /// to cancel the operation if needed.
  ///
  /// Returns: A CancelableOperation<ResultSet?> that completes with the query result
  /// or null if the operation was cancelled.
  CancelableOperation<ResultSet?> executeAsync({
    StreamController<double>? progressController,
  });

  /// Clear the params bound to the prepared statement.
  void clearBinding();

  /// Disposes this statement and releases associated memory.
  void dispose();
}
