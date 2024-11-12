import 'dart:typed_data';

import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:dart_duckdb/src/ffi/ffi.dart';
import 'package:dart_duckdb/src/impl/implementation.dart';
import 'package:dart_duckdb/src/impl/vector/array_transformer.dart';
import 'package:dart_duckdb/src/impl/vector/decimal_transformer.dart';
import 'package:dart_duckdb/src/impl/vector/enum_transformer.dart';
import 'package:dart_duckdb/src/impl/vector/list_transformer.dart';
import 'package:dart_duckdb/src/impl/vector/map_transformer.dart';
import 'package:dart_duckdb/src/impl/vector/struct_transformer.dart';
import 'package:dart_duckdb/src/impl/vector/union_transformer.dart';
import 'package:dart_duckdb/src/types/time.dart';
import 'package:dart_duckdb/src/types/time_with_offset.dart';
import 'package:uuid/uuid_value.dart';

typedef VectorTransformer<T> = T? Function(
  Bindings bindings,
  Pointer dataPtr,
  int offsetIndex,
  duckdb_vector handle,
  LogicalType logicalType,
);

// duckdb strings are stored differently based upon their length
// if the string is less than or equal to 12 characters, it is stored inline
// otherwise, it is stored as a pointer to the string
const inlineStringLimit = 12;

// Scalar transformers
int intTransformer(
  Bindings bindings,
  Pointer dataPtr,
  int offsetIndex,
  duckdb_vector handle,
  LogicalType logicalType,
) =>
    (dataPtr.cast<Int32>() + offsetIndex).value.toSigned(32);

int bigIntTransformer(
  Bindings bindings,
  Pointer dataPtr,
  int offsetIndex,
  duckdb_vector handle,
  LogicalType logicalType,
) =>
    (dataPtr.cast<Int64>() + offsetIndex).value.toSigned(64);

BigInt uBigIntTransformer(
  Bindings bindings,
  Pointer dataPtr,
  int offsetIndex,
  duckdb_vector handle,
  LogicalType logicalType,
) =>
    BigInt.from(
      (dataPtr.cast<Uint64>() + offsetIndex).value,
    ).toUnsigned(64);

BigInt hugeIntTransformer(
  Bindings bindings,
  Pointer dataPtr,
  int offsetIndex,
  duckdb_vector handle,
  LogicalType logicalType,
) {
  final lowInt64 = BigInt.from(
    (dataPtr.cast<Uint64>() + (offsetIndex * 2)).value,
  ).toUnsigned(64);
  final highInt64 = BigInt.from(
    (dataPtr.cast<Uint64>() + (offsetIndex * 2 + 1)).value,
  ).toSigned(128);
  return (highInt64 << 64) + lowInt64;
}

BigInt uHugeIntTransformer(
  Bindings bindings,
  Pointer dataPtr,
  int offsetIndex,
  duckdb_vector handle,
  LogicalType logicalType,
) {
  final lowInt64 = BigInt.from(
    (dataPtr.cast<Uint64>() + (offsetIndex * 2)).value,
  ).toUnsigned(64);
  final highInt64 = BigInt.from(
    (dataPtr.cast<Uint64>() + (offsetIndex * 2 + 1)).value,
  ).toUnsigned(64);
  return (highInt64 << 64) + lowInt64;
}

int smallIntTransformer(
  Bindings bindings,
  Pointer dataPtr,
  int offsetIndex,
  duckdb_vector handle,
  LogicalType logicalType,
) =>
    (dataPtr.cast<Int16>() + offsetIndex).value.toSigned(16);

int tinyIntTransformer(
  Bindings bindings,
  Pointer dataPtr,
  int offsetIndex,
  duckdb_vector handle,
  LogicalType logicalType,
) =>
    (dataPtr.cast<Int8>() + offsetIndex).value.toSigned(8);

int uTinyIntTransformer(
  Bindings bindings,
  Pointer dataPtr,
  int offsetIndex,
  duckdb_vector handle,
  LogicalType logicalType,
) =>
    (dataPtr.cast<Uint8>() + offsetIndex).value.toUnsigned(8);

int uSmallIntTransformer(
  Bindings bindings,
  Pointer dataPtr,
  int offsetIndex,
  duckdb_vector handle,
  LogicalType logicalType,
) =>
    (dataPtr.cast<Uint16>() + offsetIndex).value.toUnsigned(16);

int uIntegerTransformer(
  Bindings bindings,
  Pointer dataPtr,
  int offsetIndex,
  duckdb_vector handle,
  LogicalType logicalType,
) =>
    (dataPtr.cast<Uint32>() + offsetIndex).value.toUnsigned(32);

double floatTransformer(
  Bindings bindings,
  Pointer dataPtr,
  int offsetIndex,
  duckdb_vector handle,
  LogicalType logicalType,
) =>
    (dataPtr.cast<Float>() + offsetIndex).value;

double doubleTransformer(
  Bindings bindings,
  Pointer dataPtr,
  int offsetIndex,
  duckdb_vector handle,
  LogicalType logicalType,
) =>
    (dataPtr.cast<Double>() + offsetIndex).value;

bool boolTransformer(
  Bindings bindings,
  Pointer dataPtr,
  int offsetIndex,
  duckdb_vector handle,
  LogicalType logicalType,
) =>
    (dataPtr.cast<Bool>() + offsetIndex).value;

String stringTransformer(
  Bindings bindings,
  Pointer dataPtr,
  int offsetIndex,
  duckdb_vector handle,
  LogicalType logicalType,
) {
  // Cast dataPtr to Pointer<duckdb_string_t> to access the length field
  final stringPtr = dataPtr.cast<duckdb_string_t>() + offsetIndex;
  final duckdbString = stringPtr.ref.value;

  // Since both structs have the 'length' field at the same position,
  // we can access it from either 'pointer' or 'inlined'.
  final length = duckdbString.inlined.length;

  // Pointer to the start of the duckdb_string_t struct as Uint8 for byte-wise arithmetic
  final basePtr = stringPtr.cast<Uint8>();

  if (length <= 12) {
    // Inlined string: data starts at offset 4 bytes
    final inlinedDataPtr = basePtr + 4;
    return inlinedDataPtr.cast<Char>().readString(length);
  }

  // Heap string: pointer to data is at offset 8
  final ptrFieldPtr = (basePtr + 8).cast<IntPtr>();
  final ptrAddress = ptrFieldPtr.value;

  assert(ptrAddress != 0, 'Pointer to string data must not be null');
  if (ptrAddress == 0) {
    // Handle null pointer
    return '';
  }
  return Pointer<Char>.fromAddress(ptrAddress).readString(length);
}

// Bitstrings in DuckDB are variable-length strings of 1s and 0s.
// Their storage has the following characteristics:
//  Each bitstring requires 1 byte for every group of 8 bits, plus some additional metadata.
String bitstringTransformer(
  Bindings bindings,
  Pointer dataPtr,
  int offsetIndex,
  duckdb_vector handle,
  LogicalType logicalType,
) {
  final size = (dataPtr.cast<Uint32>() + (offsetIndex * 4)).value;
  Uint8List bitData;

  if (size <= inlineStringLimit) {
    bitData = (dataPtr.cast<Uint32>() + (offsetIndex * 4 + 1) as Pointer<Uint8>)
        .asTypedList(size);
  } else {
    final value = (dataPtr.cast<Uint64>() + (offsetIndex * 2 + 1)).value;
    bitData = Pointer.fromAddress(value).cast<Uint8>().asTypedList(size);
  }

  final padding = bitData[0];
  final totalBits = (size - 1) * 8 - padding;
  final result = List<int>.filled((totalBits + 7) ~/ 8, 0);
  var resultIndex = 0;
  var resultBit = 0;

  // decompress each byte, bit by bit, accounting for padding
  for (var i = 1; i < size; i++) {
    final byte = bitData[i];
    final start = (i == 1) ? padding : 0;
    for (var j = start; j < 8; j++) {
      if (resultBit == 8) {
        resultIndex++;
        resultBit = 0;
      }
      result[resultIndex] |= ((byte >> (7 - j)) & 1) << (7 - resultBit);
      resultBit++;
    }
  }

  return result
      .map((byte) => byte.toRadixString(2).padLeft(8, '0'))
      .join()
      .substring(0, totalBits);
}

Date dateTransformer(
  Bindings bindings,
  Pointer dataPtr,
  int offsetIndex,
  duckdb_vector handle,
  LogicalType logicalType,
) =>
    Date((dataPtr.cast<Int32>() + offsetIndex).value);

Time timeTransformer(
  Bindings bindings,
  Pointer dataPtr,
  int offsetIndex,
  duckdb_vector handle,
  LogicalType logicalType,
) =>
    Time.fromMicrosecondsSinceEpoch(
      (dataPtr.cast<Int64>() + offsetIndex).value,
    );

TimeWithOffset timeTzTransformer(
  Bindings bindings,
  Pointer dataPtr,
  int offsetIndex,
  duckdb_vector handle,
  LogicalType logicalType,
) {
  final bits = (dataPtr.cast<Int64>() + offsetIndex).value;
  const maxOffset = 16 * 60 * 60 - 1; // ±15:59:59
  return TimeWithOffset.fromMicrosecondsSinceEpoch(
    bits >> 24,
    maxOffset - (bits & 0xFFFFFF),
  );
}

DateTime timestampTransformer(
  Bindings bindings,
  Pointer dataPtr,
  int offsetIndex,
  duckdb_vector handle,
  LogicalType logicalType,
) =>
    DateTime.fromMicrosecondsSinceEpoch(
      (dataPtr.cast<Uint64>() + offsetIndex).value,
      isUtc: true,
    );

DateTime timestampSTransformer(
  Bindings bindings,
  Pointer dataPtr,
  int offsetIndex,
  duckdb_vector handle,
  LogicalType logicalType,
) =>
    DateTime.fromMillisecondsSinceEpoch(
      (dataPtr.cast<Uint64>() + offsetIndex).value * 1000,
      isUtc: true,
    );

DateTime timestampMSTransformer(
  Bindings bindings,
  Pointer dataPtr,
  int offsetIndex,
  duckdb_vector handle,
  LogicalType logicalType,
) =>
    DateTime.fromMillisecondsSinceEpoch(
      (dataPtr.cast<Uint64>() + offsetIndex).value,
      isUtc: true,
    );

DateTime timestampNSTransformer(
  Bindings bindings,
  Pointer dataPtr,
  int offsetIndex,
  duckdb_vector handle,
  LogicalType logicalType,
) =>
    DateTime.fromMicrosecondsSinceEpoch(
      (dataPtr.cast<Uint64>() + offsetIndex).value ~/ 1000,
      isUtc: true,
    );

DateTime timestampTzTransformer(
  Bindings bindings,
  Pointer dataPtr,
  int offsetIndex,
  duckdb_vector handle,
  LogicalType logicalType,
) =>
    DateTime.fromMicrosecondsSinceEpoch(
      (dataPtr.cast<Uint64>() + offsetIndex).value,
      isUtc: true,
    );

Interval? intervalTransformer(
  Bindings bindings,
  Pointer dataPtr,
  int offsetIndex,
  duckdb_vector handle,
  LogicalType logicalType,
) {
  final interval = (dataPtr.cast<duckdb_interval>() + offsetIndex).ref;
  return Interval(
    months: interval.months,
    days: interval.days,
    microseconds: interval.micros,
  );
}

Uint8List blobTransformer(
  Bindings bindings,
  Pointer dataPtr,
  int offsetIndex,
  duckdb_vector handle,
  LogicalType logicalType,
) {
  final size = (dataPtr.cast<Uint32>() + (offsetIndex * 4)).value;
  if (size <= inlineStringLimit) {
    return (dataPtr.cast<Uint32>() + (offsetIndex * 4 + 1) as Pointer<Uint8>)
        .asTypedList(size);
  } else {
    final value = (dataPtr.cast<Uint64>() + (offsetIndex * 2 + 1)).value;
    return Pointer.fromAddress(value).cast<Uint8>().asTypedList(size);
  }
}

UuidValue uuidTransformer(
  Bindings bindings,
  Pointer dataPtr,
  int offsetIndex,
  duckdb_vector handle,
  LogicalType logicalType,
) {
  final highBytes = (dataPtr.cast<Uint64>() + (offsetIndex * 2 + 1))
      .cast<Uint8>()
      .asTypedList(8);
  final lowBytes =
      (dataPtr.cast<Uint64>() + (offsetIndex * 2)).cast<Uint8>().asTypedList(8);

  final uuidBytes = Uint8List(16);
  uuidBytes.setRange(0, 8, highBytes.reversed);
  uuidBytes.setRange(8, 16, lowBytes.reversed);

  uuidBytes[0] = uuidBytes[0] ^ 0x80;

  return UuidValue.fromByteList(uuidBytes);
}

VectorTransformer<T?> getTransformerForType<T>(DatabaseType dbType) {
  return switch (dbType) {
    DatabaseType.tinyInt => tinyIntTransformer,
    DatabaseType.smallInt => smallIntTransformer,
    DatabaseType.integer => intTransformer,
    DatabaseType.uTinyInt => uTinyIntTransformer,
    DatabaseType.uSmallInt => uSmallIntTransformer,
    DatabaseType.uInteger => uIntegerTransformer,
    DatabaseType.bigInt => bigIntTransformer,
    DatabaseType.hugeInt => hugeIntTransformer,
    DatabaseType.uBigInt => uBigIntTransformer,
    DatabaseType.uHugeInt => uHugeIntTransformer,
    DatabaseType.boolean => boolTransformer,
    DatabaseType.float => floatTransformer,
    DatabaseType.double => doubleTransformer,
    DatabaseType.varchar => stringTransformer,
    DatabaseType.bitString => bitstringTransformer,
    DatabaseType.timestamp => timestampTransformer,
    DatabaseType.timestampS => timestampSTransformer,
    DatabaseType.timestampMS => timestampMSTransformer,
    DatabaseType.timestampNS => timestampNSTransformer,
    DatabaseType.timestampTz => timestampTzTransformer,
    DatabaseType.date => dateTransformer,
    DatabaseType.time => timeTransformer,
    DatabaseType.timeTz => timeTzTransformer,
    DatabaseType.interval => intervalTransformer,
    DatabaseType.blob => blobTransformer,
    DatabaseType.uuid => uuidTransformer,
    DatabaseType.array => arrayTransformer<Object?>,
    DatabaseType.list => listTransformer<Object?>,
    DatabaseType.structure => structTransformer<Object?>,
    DatabaseType.decimal => decimalTransformer,
    DatabaseType.enumeration => enumTransformer,
    DatabaseType.union => unionTransformer,
    DatabaseType.map => mapTransformer<Object, Object?>,
    _ => throw UnsupportedError('Unsupported database type: $dbType'),
  } as VectorTransformer<T?>;
}
