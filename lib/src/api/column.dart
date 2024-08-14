/// A DuckDB result set column
///
/// DuckDB columns represent a vertical slice of a result set table.
abstract class Column {
  /// The object at the given [index] in the list.
  ///
  /// The [index] must be a valid index of this list,
  /// which means that `index` must be non-negative and
  /// less than [length].
  dynamic operator [](int index);
}
