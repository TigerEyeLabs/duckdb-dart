import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:dart_duckdb/src/ffi/ffi.dart';

abstract class ValueCreator<T> {
  duckdb_value createValue(Bindings bindings, T value);
  DatabaseType get databaseType;
}
