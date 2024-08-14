import 'dart:ffi';

/// An open DuckDB database using `dart:ffi`.
abstract class Appender {
  /// The native appender handle from DuckDB.
  ///
  /// This returns a pointer to the opaque DuckDB structure as defined in the FFI.
  Pointer<void> get handle;

  /// Closes the appender and releases associated resources.
  void dispose();

  /// Appends a value for the current row of the specified type.
  ///
  /// Appends are done in a row-wise format. For each column in a row,
  /// an `append` call should be made. After appending all columns,
  /// `endRow` should be called to complete the row.
  ///
  /// @param value: The value to append.
  /// @throws DuckDBException if a value of this type was not expected
  /// in the appender's current state.
  void append(dynamic value);

  /// Marks the end of the current row.
  ///
  /// After all columns for a row have been appended, `endRow` must be
  /// called to signal that the row is complete and ready to be added
  /// to the database.
  ///
  /// @throws DuckDBException if the row could not be completed
  /// in its current state.
  void endRow();

  /// Flushes pending rows to the database.
  ///
  /// To enhance performance, the appender writes rows to the database in
  /// batches. Use `flush` to immediately write any pending rows.
  ///
  /// @throws DuckDBException if the pending rows failed to be written
  /// to the database.
  void flush();
}
