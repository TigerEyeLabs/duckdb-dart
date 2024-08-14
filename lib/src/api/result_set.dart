import 'dart:ffi';

import 'package:dart_duckdb/src/api/column.dart';
import 'package:dart_duckdb/src/api/database_type.dart';

/// An object representing a DuckDB result set
///
/// A DuckDB result set contains the data returned from the database after a
/// successful query.
///
/// A result set is organized into vertical table slices called columns.
abstract class ResultSet {
  /// The number of chunks in the result set
  int get chunkCount;

  /// The number of columns in the result set
  int get columnCount;

  /// The total number of rows in the result set
  int get rowCount;

  /// The names of the columns in the result set
  List<String> get columnNames;

  /// The duckdb data types of the columns in the result set
  List<int> get columnTypes;

  /// The native database result handle from duckdb.
  Pointer<void> get handle;

  /// The object at the given [index] in the list.
  ///
  /// The [index] must be a valid index of this list,
  /// which means that `index` must be non-negative and
  /// less than [columnCount].
  Column operator [](int index);

  /// Fetch the next row of a query result set, returning a single sequence,
  /// or null when no more data is available.
  List? fetchOne();

  /// Fetch all (remaining) rows of a query result, returning them
  /// as a sequence of sequences (e.g. a list of lists). Return an
  /// empty list when no more data is available.
  List<List> fetchAll();

  /// Retrieves the database type for the column.
  DatabaseType columnDataType(int columnIndex);

  /// Closes this result and releases associated resources.
  void dispose();
}
