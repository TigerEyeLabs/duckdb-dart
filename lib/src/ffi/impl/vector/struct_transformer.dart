import 'dart:ffi';

import 'package:dart_duckdb/src/ffi/duckdb.g.dart';
import 'package:dart_duckdb/src/ffi/impl/implementation.dart';
import 'package:dart_duckdb/src/ffi/impl/utils.dart';
import 'package:dart_duckdb/src/ffi/impl/vector/transformer_registry.dart';

Map<String, T?> structTransformer<T>(
  Bindings bindings,
  Pointer dataPtr,
  int offsetIndex,
  duckdb_vector handle,
  LogicalType logicalType,
) {
  final logicalTypeHandle = logicalType.handle.value;
  final count = bindings.duckdb_struct_type_child_count(logicalTypeHandle);
  final fields = <String, T?>{};

  for (var childIndex = 0; childIndex < count; childIndex++) {
    final childNamePtr = bindings.duckdb_struct_type_child_name(
      logicalTypeHandle,
      childIndex,
    );
    final childName = childNamePtr.readString();
    bindings.duckdb_free(childNamePtr.cast<Void>());

    final child = bindings.duckdb_struct_vector_get_child(
      handle,
      childIndex,
    );

    final validityMasksRaw = bindings.duckdb_vector_get_validity(child);
    final validityMasks =
        validityMasksRaw.isNullPointer ? null : validityMasksRaw.cast<Uint64>();

    if (validityMasks?.isElementNull(offsetIndex) ?? false) {
      fields[childName] = null;
    } else {
      final childLogicalType = child.logicalType();

      try {
        final transformer = getTransformerForType(
          childLogicalType.dataType,
        );

        final childDataPtr = bindings.duckdb_vector_get_data(child);
        fields[childName] = transformer(
          bindings,
          childDataPtr,
          offsetIndex,
          child,
          childLogicalType,
        ) as T?;
      } finally {
        childLogicalType.dispose();
      }
    }
  }

  return fields;
}
