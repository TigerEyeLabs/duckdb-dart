import 'package:dart_duckdb/src/ffi/duckdb.g.dart';
import 'package:dart_duckdb/src/ffi/impl/database_type_native.dart';

abstract class ValueCreator<T> {
  duckdb_value createValue(Bindings bindings, T value);
  DatabaseTypeNative get databaseType;
}
