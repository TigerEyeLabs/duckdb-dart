import 'package:dart_duckdb/src/ffi/ffi.dart';
import 'package:dart_duckdb/src/impl/implementation.dart';
import 'package:dart_duckdb/src/impl/utils.dart';
import 'package:dart_duckdb/src/impl/vector/transformer_registry.dart';

List<T?> listTransformer<T>(
  Bindings bindings,
  Pointer<NativeType> dataPtr,
  int offsetIndex,
  duckdb_vector handle,
  LogicalType logicalType,
) {
  // Retrieve the child vector handle for the list elements
  final child = bindings.duckdb_list_vector_get_child(handle);
  final count = bindings.duckdb_list_vector_get_size(handle);

  final childLogicalType = child.logicalType();

  try {
    // Access the list_entry_t at the given offsetIndex
    final entryPtr = dataPtr.cast<duckdb_list_entry>() + offsetIndex;
    final childOffset = entryPtr.ref.offset;
    final childLength = entryPtr.ref.length;

    // Ensure that childOffset + childLength does not exceed the child vector size
    assert(
      childOffset + childLength <= count,
      "List elements exceed child vector bounds: ${childOffset + childLength} > $count",
    );

    final validityMasksRaw = bindings.duckdb_vector_get_validity(child);
    final validityMasks =
        validityMasksRaw.isNullPointer ? null : validityMasksRaw.cast<Uint64>();

    final elementTransformer = getTransformerForType<T>(
      childLogicalType.dataType,
    );
    final childDataPtr = bindings.duckdb_vector_get_data(child);

    return List.generate(
      childLength,
      (index) {
        final elementOffset = childOffset + index;

        // Ensure elementOffset is within bounds
        if (elementOffset >= count) {
          throw Exception(
            'Element offset $elementOffset out of bounds for child vector of size $count',
          );
        }

        // Check for null in the validity mask
        if (validityMasks?.isElementNull(elementOffset) ?? false) {
          return null;
        }

        // Transform the element
        return elementTransformer(
          bindings,
          childDataPtr,
          elementOffset,
          child,
          childLogicalType,
        );
      },
      growable: false,
    );
  } finally {
    childLogicalType.dispose();
  }
}
