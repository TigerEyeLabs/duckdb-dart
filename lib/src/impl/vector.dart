part of 'implementation.dart';

class Vector {
  final Bindings bindings;

  final int count;
  final int offset;
  final LogicalType logicalType;
  final duckdb_vector handle;

  static const inlineStringLimit = 12;

  Vector(
    this.bindings,
    this.handle,
    this.count, {
    this.offset = 0,
    LogicalType? logicalType,
  }) : logicalType = logicalType ?? handle.logicalType();

  bool unwrapNull(int index) {
    assert(index < count, "vector index out of bounds $index >= $count");
    final offsetIndex = offset + index;
    final validityMasks = bindings.duckdb_vector_get_validity(handle);
    if (validityMasks.isNullPointer) {
      return false;
    }

    final validityEntryIndex = offsetIndex ~/ 64;
    final validityBitIndex = offsetIndex % 64;
    final validityMask = (Pointer<Uint64>.fromAddress(validityMasks.address) +
            validityEntryIndex)[0]
        .toUnsigned(64);
    final validityBit = 1 << validityBitIndex;
    return (validityMask & validityBit) == 0;
  }

  dynamic unwrap(int index) {
    final offsetIndex = offset + index;
    final dataPtr = bindings.duckdb_vector_get_data(handle);
    return _value(logicalType.dataType, dataPtr, offsetIndex);
  }

  dynamic _value(DatabaseType type, Pointer dataPtr, int offsetIndex) {
    switch (type) {
      case DatabaseType.hugeInt:
        {
          final lowInt64 = BigInt.from(
            (dataPtr.cast<Uint64>() + (offsetIndex * 2)).value,
          ).toUnsigned(64);
          final highInt64 = BigInt.from(
            (dataPtr.cast<Uint64>() + (offsetIndex * 2 + 1)).value,
          ).toSigned(128);
          return (highInt64 << 64) + lowInt64;
        }
      case DatabaseType.uHugeInt:
        {
          final lowInt64 = BigInt.from(
            (dataPtr.cast<Uint64>() + (offsetIndex * 2)).value,
          ).toUnsigned(64);

          final highInt64 = BigInt.from(
            (dataPtr.cast<Uint64>() + (offsetIndex * 2 + 1)).value,
          ).toUnsigned(64);
          return (highInt64 << 64) + lowInt64;
        }
      case DatabaseType.bigInt:
        return (dataPtr.cast<Int64>() + offsetIndex).value.toSigned(64);
      case DatabaseType.integer:
        return (dataPtr.cast<Int32>() + offsetIndex).value.toSigned(32);
      case DatabaseType.smallInt:
        return (dataPtr.cast<Int16>() + offsetIndex).value.toSigned(16);
      case DatabaseType.tinyInt:
        return (dataPtr.cast<Int8>() + offsetIndex).value.toSigned(8);
      case DatabaseType.uBigInt:
        return BigInt.from((dataPtr.cast<Uint64>() + offsetIndex).value)
            .toUnsigned(64);
      case DatabaseType.uInteger:
        return (dataPtr.cast<Uint32>() + offsetIndex).value.toUnsigned(32);
      case DatabaseType.uSmallInt:
        return (dataPtr.cast<Uint16>() + offsetIndex).value.toUnsigned(16);
      case DatabaseType.uTinyInt:
        return (dataPtr.cast<Uint8>() + offsetIndex).value.toUnsigned(8);
      case DatabaseType.float:
        return (dataPtr.cast<Float>() + offsetIndex).value;
      case DatabaseType.double:
        return (dataPtr.cast<Double>() + offsetIndex).value;
      case DatabaseType.decimal:
        {
          final props = logicalType.decimalProperties();
          final storageValue = _value(props.type, dataPtr, offsetIndex);

          if (storageValue is BigInt) {
            return Decimal(storageValue, props.scale);
          } else if (storageValue is num) {
            return Decimal(BigInt.from(storageValue), props.scale);
          }

          throw DuckDBException("Dart Unsupported Decimal type $storageValue");
        }
      case DatabaseType.boolean:
        return (dataPtr.cast<Bool>() + offsetIndex).value;
      case DatabaseType.varchar:
        {
          final size = (dataPtr.cast<Uint32>() + (offsetIndex * 4)).value;
          if (size <= inlineStringLimit) {
            return (dataPtr.cast<Uint32>() + (offsetIndex * 4 + 1)
                    as Pointer<Char>)
                .readString(size);
          } else {
            final value =
                (dataPtr.cast<Uint64>() + (offsetIndex * 2 + 1)).value;
            return Pointer.fromAddress(value).cast<Char>().readString(size);
          }
        }
      case DatabaseType.date:
        return Date((dataPtr.cast<Int32>() + offsetIndex).value);
      case DatabaseType.timestampTz:
      case DatabaseType.timestamp:
        return DateTime.fromMicrosecondsSinceEpoch(
          (dataPtr.cast<Uint64>() + offsetIndex).value,
          isUtc: true,
        );
      case DatabaseType.timestampS:
        return DateTime.fromMillisecondsSinceEpoch(
          (dataPtr.cast<Uint64>() + offsetIndex).value * 1000,
          isUtc: true,
        );
      case DatabaseType.timestampMS:
        return DateTime.fromMillisecondsSinceEpoch(
          (dataPtr.cast<Uint64>() + offsetIndex).value,
          isUtc: true,
        );
      case DatabaseType.timestampNS:
        return DateTime.fromMicrosecondsSinceEpoch(
          (dataPtr.cast<Uint64>() + offsetIndex).value ~/ 1000,
          isUtc: true,
        );
      case DatabaseType.list:
        {
          final child = bindings.duckdb_list_vector_get_child(handle);
          final count = bindings.duckdb_list_vector_get_size(handle);
          final childOffset =
              (dataPtr.cast<Uint64>() + (offsetIndex * 2)).value.toUnsigned(64);
          final childLength = (dataPtr.cast<Uint64>() + (offsetIndex * 2 + 1))
              .value
              .toUnsigned(64);

          final childVector =
              Vector(bindings, child, count, offset: childOffset);
          return List.generate(
            childLength,
            (index) {
              if (childVector.unwrapNull(index)) {
                return null;
              }
              return childVector.unwrap(index);
            },
            growable: false,
          );
        }
      case DatabaseType.structure:
        {
          final logicalTypeHandle = logicalType.handle.value;
          final count =
              bindings.duckdb_struct_type_child_count(logicalTypeHandle);
          final fields = <String, dynamic>{};

          for (var childIndex = 0; childIndex < count; childIndex++) {
            final child =
                bindings.duckdb_struct_vector_get_child(handle, childIndex);
            final childVector =
                Vector(bindings, child, count, offset: offsetIndex);
            final childNamePtr = bindings.duckdb_struct_type_child_name(
              logicalTypeHandle,
              childIndex,
            );
            final childName = childNamePtr.readString();
            bindings.duckdb_free(childNamePtr.cast<Void>());

            if (childVector.unwrapNull(0)) {
              fields[childName] = null;
            } else {
              fields[childName] = childVector.unwrap(0);
            }
          }

          return fields;
        }
      case DatabaseType.time:
        return Time.fromMicrosecondsSinceEpoch(
          (dataPtr.cast<Int64>() + offsetIndex).value,
        );
      case DatabaseType.interval:
        {
          final interval = (dataPtr.cast<duckdb_interval>() + offsetIndex).ref;
          final months = interval.months;
          final days = interval.days;
          final microseconds = interval.micros;
          return Interval(
            months: months,
            days: days,
            microseconds: microseconds,
          );
        }
      case DatabaseType.uuid:
        {
          final highBytes = (dataPtr.cast<Uint64>() + (offsetIndex * 2 + 1))
              .cast<Uint8>()
              .asTypedList(8);
          final lowBytes = (dataPtr.cast<Uint64>() + (offsetIndex * 2))
              .cast<Uint8>()
              .asTypedList(8);

          // Combine the low and high bytes into a single list
          final uuidBytes = Uint8List(16);
          uuidBytes.setRange(0, 8, highBytes.reversed);
          uuidBytes.setRange(8, 16, lowBytes.reversed);

          // Apply a bit flip to the most significant bit of the first byte
          uuidBytes[0] = uuidBytes[0] ^ 0x80;

          return UuidValue.fromByteList(uuidBytes);
        }
      case DatabaseType.enumeration:
        final logicalTypeHandle = logicalType.handle.value;
        final enumType = bindings.duckdb_enum_internal_type(logicalTypeHandle);
        final databaseType = DatabaseType.values[enumType];

        return List.generate(
          count,
          (index) {
            final idx = _value(databaseType, dataPtr, index);
            return bindings
                .duckdb_enum_dictionary_value(logicalTypeHandle, idx)
                .cast<Utf8>()
                .toDartString();
          },
          growable: false,
        );
      case DatabaseType.array:
        {
          final child = bindings.duckdb_array_vector_get_child(handle);
          final count =
              bindings.duckdb_array_type_array_size(logicalType.handle.value);
          final childVector =
              Vector(bindings, child, count, offset: offsetIndex * count);

          return List.generate(
            count,
            (index) {
              if (childVector.unwrapNull(index)) {
                return null;
              }
              return childVector.unwrap(index);
            },
            growable: false,
          );
        }
      case DatabaseType.blob:
      case DatabaseType.map:
      case DatabaseType.union:
      case DatabaseType.bit:
      case DatabaseType.timeTz:
        throw DuckDBException("Dart Unsupported Vector type $type");
      case DatabaseType.invalid:
        throw DuckDBException("Dart Invalid Vector type $type");

      // TODO: Handle this case.
    }
  }
}
