import 'package:dart_duckdb/src/ffi/ffi.dart';
import 'package:dart_duckdb/src/impl/implementation.dart';
import 'package:dart_duckdb/src/impl/utils.dart';
import 'package:dart_duckdb/src/impl/vector/transformer_registry.dart';

Map<K, V?> mapTransformer<K, V>(
  Bindings bindings,
  Pointer dataPtr,
  int offsetIndex,
  duckdb_vector handle,
  LogicalType logicalType,
) {
  // Retrieve the child vector of the list vector, which contains the key-value pairs
  final structVector = bindings.duckdb_list_vector_get_child(handle);

  // Access the duckdb_list_entry at the given offsetIndex to get the start offset and length
  final entryPtr = dataPtr.cast<duckdb_list_entry>() + offsetIndex;
  final startOffset = entryPtr.ref.offset;
  final length = entryPtr.ref.length;

  // Get the total number of elements in the child vector
  final childCount = bindings.duckdb_list_vector_get_size(handle);

  // Ensure that the offsets are within bounds
  assert(
    startOffset + length <= childCount,
    "List elements exceed child vector bounds: ${startOffset + length} > $childCount",
  );

  // Get the key and value vectors from the struct vector
  final keyVector = bindings.duckdb_struct_vector_get_child(structVector, 0);
  final valueVector = bindings.duckdb_struct_vector_get_child(structVector, 1);

  // Get the logical types for key and value
  final keyLogicalType = keyVector.logicalType();
  final valueLogicalType = valueVector.logicalType();

  try {
    // Get transformers for key and value types
    final keyTransformer = getTransformerForType<K>(keyLogicalType.dataType);
    final valueTransformer =
        getTransformerForType<V>(valueLogicalType.dataType);

    // Get data pointers for key and value vectors
    final keyDataPtr = bindings.duckdb_vector_get_data(keyVector);
    final valueDataPtr = bindings.duckdb_vector_get_data(valueVector);

    // Get validity masks for key and value vectors
    final keyValidityMaskRaw = bindings.duckdb_vector_get_validity(keyVector);
    final keyValidityMask = keyValidityMaskRaw.isNullPointer
        ? null
        : keyValidityMaskRaw.cast<Uint64>();

    final valueValidityMaskRaw =
        bindings.duckdb_vector_get_validity(valueVector);
    final valueValidityMask = valueValidityMaskRaw.isNullPointer
        ? null
        : valueValidityMaskRaw.cast<Uint64>();

    final map = <K, V?>{};

    for (var i = 0; i < length; i++) {
      final elementIndex = startOffset + i;

      assert(
        !(keyValidityMask?.isElementNull(elementIndex) ?? false),
        'Key cannot be null',
      );

      // Transform the key
      final key = keyTransformer(
        bindings,
        keyDataPtr,
        elementIndex,
        keyVector,
        keyLogicalType,
      ) as K;

      // Check if the value is null
      final isValueNull =
          valueValidityMask?.isElementNull(elementIndex) ?? false;

      // Transform the value
      final value = isValueNull
          ? null
          : valueTransformer(
              bindings,
              valueDataPtr,
              elementIndex,
              valueVector,
              valueLogicalType,
            ) as V;

      // Add the key-value pair to the map
      map[key] = value;
    }

    return map;
  } finally {
    // Dispose of the logical types to prevent memory leaks
    keyLogicalType.dispose();
    valueLogicalType.dispose();
  }
}
