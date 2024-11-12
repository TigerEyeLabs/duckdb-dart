import 'package:dart_duckdb/src/ffi/ffi.dart';
import 'package:dart_duckdb/src/impl/implementation.dart';
import 'package:dart_duckdb/src/impl/utils.dart';
import 'package:dart_duckdb/src/impl/vector/transformer_registry.dart';

List<T?> arrayTransformer<T>(
  Bindings bindings,
  Pointer<NativeType> dataPtr,
  int offsetIndex,
  duckdb_vector handle,
  LogicalType logicalType,
) {
  // Retrieve the child vector handle for the array elements
  final childHandle = bindings.duckdb_array_vector_get_child(handle);
  final childLogicalType = childHandle.logicalType();

  try {
    final elementTransformer = getTransformerForType<T>(
      childLogicalType.dataType,
    );

    // Get array size from logical type
    final arraySize =
        bindings.duckdb_array_type_array_size(logicalType.handle.value);

    // For arrays, the offset is multiplied by the array size
    // since all elements are stored contiguously
    final childOffset = offsetIndex * arraySize;

    // Pointer to the child data
    final childDataPtr = bindings.duckdb_vector_get_data(childHandle);

    final validityMasksRaw = bindings.duckdb_vector_get_validity(childHandle);
    final validityMasks =
        validityMasksRaw.isNullPointer ? null : validityMasksRaw.cast<Uint64>();

    return List.generate(
      arraySize,
      (index) {
        final elementOffset = childOffset + index;
        // If validityMasks is null, all values are valid so proceed with transformation
        // Otherwise check if the specific element is valid
        if (validityMasks?.isElementNull(elementOffset) ?? false) {
          return null;
        }
        return elementTransformer(
          bindings,
          childDataPtr,
          elementOffset,
          childHandle,
          childLogicalType,
        );
      },
      growable: false,
    );
  } finally {
    childLogicalType.dispose();
  }
}
