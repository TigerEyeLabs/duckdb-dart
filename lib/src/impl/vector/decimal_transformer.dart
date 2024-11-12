import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:dart_duckdb/src/ffi/ffi.dart';
import 'package:dart_duckdb/src/impl/implementation.dart';
import 'package:dart_duckdb/src/impl/vector/transformer_registry.dart';

Decimal decimalTransformer(
  Bindings bindings,
  Pointer<NativeType> dataPtr,
  int offsetIndex,
  duckdb_vector handle,
  LogicalType logicalType,
) {
  final props = logicalType.decimalProperties();

  // Get the appropriate transformer for the storage type
  final storageTransformer = switch (props.type) {
    DatabaseType.smallInt => smallIntTransformer,
    DatabaseType.integer => intTransformer,
    DatabaseType.bigInt => bigIntTransformer,
    DatabaseType.hugeInt => hugeIntTransformer,
    _ => throw UnsupportedError(
        'Unsupported decimal storage type: ${props.type}',
      ),
  };

  // Get the storage value
  final storageValue = storageTransformer(
    bindings,
    dataPtr,
    offsetIndex,
    handle,
    logicalType,
  );

  // Convert to BigInt if needed and create Decimal
  if (storageValue is BigInt) {
    return Decimal(storageValue, props.scale);
  } else if (storageValue is num) {
    return Decimal(BigInt.from(storageValue), props.scale);
  }

  throw UnsupportedError(
    'Unsupported decimal storage value type: ${storageValue.runtimeType}',
  );
}