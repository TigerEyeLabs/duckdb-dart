import 'package:dart_duckdb/src/ffi/ffi.dart';
import 'package:dart_duckdb/src/impl/implementation.dart';
import 'package:dart_duckdb/src/impl/utils.dart';
import 'package:dart_duckdb/src/impl/vector/transformer_registry.dart';

Object? unionTransformer(
  Bindings bindings,
  Pointer<NativeType> dataPtr,
  int offsetIndex,
  duckdb_vector handle,
  LogicalType logicalType,
) {
  // Unions in duckdb are tagged unions and are stored as a struct internally, with tag as first member
  final tagVectorHandle = bindings.duckdb_struct_vector_get_child(handle, 0);
  final tagLogicalType = tagVectorHandle.logicalType();

  try {
    // Get the tag value (indicates which member is active)
    final tagTransformer = getTransformerForType<int>(
      tagLogicalType.dataType,
    );
    final tagValue = tagTransformer(
      bindings,
      bindings.duckdb_vector_get_data(tagVectorHandle),
      offsetIndex,
      tagVectorHandle,
      tagLogicalType,
    );

    // Get the active member's vector (offset by 1 since tag is at 0)
    final memberVectorHandle = bindings.duckdb_struct_vector_get_child(
      handle,
      tagValue! + 1,
    );
    final memberLogicalType = memberVectorHandle.logicalType();

    try {
      // Get transformer for the active member's type
      final memberTransformer = getTransformerForType(
        memberLogicalType.dataType,
      );

      // Check if the member value is null
      final validityMasks =
          bindings.duckdb_vector_get_validity(memberVectorHandle);
      if (validityMasks.isElementNull(offsetIndex)) return null;

      // Transform and return the member value
      return memberTransformer(
        bindings,
        bindings.duckdb_vector_get_data(memberVectorHandle),
        offsetIndex,
        memberVectorHandle,
        memberLogicalType,
      );
    } finally {
      memberLogicalType.dispose();
    }
  } finally {
    tagLogicalType.dispose();
  }
}
