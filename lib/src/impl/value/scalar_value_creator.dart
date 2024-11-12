import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:dart_duckdb/src/ffi/ffi.dart';
import 'package:dart_duckdb/src/impl/value/value_creator.dart';

class ScalarValueCreator<T> implements ValueCreator<T> {
  final DatabaseType _databaseType;
  final duckdb_value Function(Bindings bindings, T value) _creator;

  const ScalarValueCreator(this._databaseType, this._creator);

  @override
  duckdb_value createValue(Bindings bindings, T value) =>
      _creator(bindings, value);

  @override
  DatabaseType get databaseType => _databaseType;
}
