import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:dart_duckdb/src/ffi/ffi.dart';
import 'package:dart_duckdb/src/impl/implementation.dart';
import 'package:dart_duckdb/src/impl/value/value_creator.dart';

class ListValueCreator<E> implements ValueCreator<List<E>> {
  final ValueCreator<E> _elementHandler;

  const ListValueCreator(this._elementHandler);

  @override
  DatabaseType get databaseType => _elementHandler.databaseType;

  @override
  duckdb_value createValue(Bindings bindings, List<E> list) {
    if (list.isEmpty) {
      return _createEmptyListValue(bindings);
    }

    final childType = LogicalType.fromDatabaseType(databaseType);
    final valuesArray = allocate<duckdb_value>(list.length);
    final valuePointers = List.generate(
      list.length,
      (_) => allocate<duckdb_value>(),
      growable: false,
    );

    try {
      for (var i = 0; i < list.length; i++) {
        valuesArray[i] = _elementHandler.createValue(bindings, list[i]);
        valuePointers[i].value = valuesArray[i];
      }

      return bindings.duckdb_create_list_value(
        childType.handle.value,
        valuesArray,
        list.length,
      );
    } finally {
      // Clean up individual values
      for (var i = 0; i < list.length; i++) {
        bindings.duckdb_destroy_value(valuePointers[i]);
        valuePointers[i].free();
      }

      childType.dispose();
      valuesArray.free();
    }
  }

  static duckdb_value _createEmptyListValue(Bindings bindings) {
    final childType = LogicalType.fromDatabaseType(DatabaseType.double);
    final valuesArray = allocate<duckdb_value>(0);

    try {
      return bindings.duckdb_create_list_value(
        childType.handle.value,
        valuesArray,
        0,
      );
    } finally {
      childType.dispose();
      valuesArray.free();
    }
  }
}
