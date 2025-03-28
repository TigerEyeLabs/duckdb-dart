import 'package:dart_duckdb/src/ffi/duckdb.g.dart';
import 'package:dart_duckdb/src/ffi/impl/database_type_native.dart';
import 'package:dart_duckdb/src/ffi/impl/value/value_creator.dart';

class ScalarValueCreator<T> implements ValueCreator<T> {
  final DatabaseTypeNative _databaseType;
  final duckdb_value Function(Bindings bindings, T value) _creator;

  const ScalarValueCreator(this._databaseType, this._creator);

  @override
  duckdb_value createValue(Bindings bindings, T value) =>
      _creator(bindings, value);

  @override
  DatabaseTypeNative get databaseType => _databaseType;
}
