import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:dart_duckdb/src/ffi/ffi.dart';
import 'package:dart_duckdb/src/impl/implementation.dart';
import 'package:dart_duckdb/src/impl/vector/transformer_registry.dart';
import 'package:ffi/ffi.dart';

String enumTransformer(
  Bindings bindings,
  Pointer<NativeType> dataPtr,
  int offsetIndex,
  duckdb_vector handle,
  LogicalType logicalType,
) {
  final logicalTypeHandle = logicalType.handle.value;
  final enumType = bindings.duckdb_enum_internal_type(logicalTypeHandle);
  final databaseType = DatabaseType.values[enumType];

  final enumLogicalType = LogicalType.fromDatabaseType(databaseType);

  try {
    // Get the appropriate transformer for the storage type
    final storageTransformer = getTransformerForType(databaseType);

    // Get the index value
    final idx = storageTransformer(
      bindings,
      dataPtr,
      offsetIndex,
      handle,
      enumLogicalType,
    );

    return bindings
        .duckdb_enum_dictionary_value(logicalTypeHandle, idx)
        .cast<Utf8>()
        .toDartString();
  } finally {
    enumLogicalType.dispose();
  }
}