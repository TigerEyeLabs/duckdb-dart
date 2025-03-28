import 'dart:ffi';
import 'dart:typed_data';

import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:dart_duckdb/src/ffi/duckdb.g.dart';
import 'package:dart_duckdb/src/ffi/impl/database_type_native.dart';
import 'package:dart_duckdb/src/ffi/impl/implementation.dart';
import 'package:dart_duckdb/src/ffi/impl/utils.dart';
import 'package:dart_duckdb/src/ffi/impl/value/list_value_creator.dart';
import 'package:dart_duckdb/src/ffi/impl/value/value_creator.dart';
import 'package:dart_duckdb/src/ffi/impl/value/value_factory.dart';
import 'package:dart_duckdb/src/types/time.dart';
import 'package:dart_duckdb/src/types/time_with_offset.dart';
import 'package:ffi/ffi.dart';

/// https://github.com/duckdb/duckdb/blob/main/test/api/capi/test_capi_complex_types.cpp
class StructValueCreator implements ValueCreator<Map<String, Object>> {
  @override
  DatabaseTypeNative get databaseType => DatabaseTypeNative.structure;

  const StructValueCreator();

  @override
  duckdb_value createValue(Bindings bindings, Map<String, Object> map) {
    if (map.isEmpty) {
      throw Exception('Struct cannot be empty');
    }

    // Build field handlers dynamically based on value types
    final fieldHandlers = <String, ValueCreator>{};
    for (final entry in map.entries) {
      fieldHandlers[entry.key] = _getHandlerForValue(entry.value);
    }

    final valuesArray = allocate<duckdb_value>(map.length);
    final valuePointers = List.generate(
      map.length,
      (_) => allocate<duckdb_value>(),
      growable: false,
    );

    try {
      var i = 0;
      for (final entry in map.entries) {
        final handler = fieldHandlers[entry.key]!;
        valuesArray[i] = handler.createValue(bindings, entry.value);
        valuePointers[i].value = valuesArray[i];
        i++;
      }

      final memberTypes = fieldHandlers.values.map((h) {
        final baseType = LogicalType.fromDatabaseType(h.databaseType);
        if (h is ListValueCreator) {
          final listType = allocate<duckdb_logical_type>();
          listType.value =
              bindings.duckdb_create_list_type(baseType.handle.value);
          final result = LogicalType.withLogicalType(listType);
          baseType.dispose();
          return result;
        } else if (h is StructValueCreator) {
          // For nested structs, we need to get their inner structure
          final nestedMap =
              map[fieldHandlers.keys.elementAt(i - 1)]! as Map<String, Object>;
          final nestedHandlers = nestedMap.map(
            (key, value) => MapEntry(key, _getHandlerForValue(value)),
          );

          final nestedTypes = nestedHandlers.values
              .map((h) => LogicalType.fromDatabaseType(h.databaseType))
              .toList();
          final nestedNames = nestedHandlers.keys.toList();

          try {
            final result =
                _createStructType(bindings, nestedTypes, nestedNames);
            return result;
          } finally {
            for (final type in nestedTypes) {
              type.dispose();
            }
            baseType.dispose();
          }
        }
        return baseType;
      }).toList();

      final memberNames = fieldHandlers.keys.toList();
      final structType = _createStructType(bindings, memberTypes, memberNames);

      try {
        return bindings.duckdb_create_struct_value(
          structType.handle.value,
          valuesArray,
        );
      } finally {
        for (var i = 0; i < memberTypes.length; i++) {
          memberTypes[i].dispose();
        }
        structType.dispose();
      }
    } finally {
      // Clean up individual values
      for (var i = 0; i < map.length; i++) {
        bindings.duckdb_destroy_value(valuePointers[i]);
        valuePointers[i].free();
      }

      valuesArray.free();
    }
  }

  ValueCreator _getHandlerForValue(Object value) {
    // First try to get handler for single values
    if (value is! List<Object>) {
      return _getSingleValueHandler(value);
    }

    // Handle List types
    return _getListValueHandler(value);
  }

  ValueCreator _getSingleValueHandler(Object value) {
    return switch (value) {
      int() => ValueFactory.intCreator,
      bool() => ValueFactory.boolCreator,
      double() => ValueFactory.doubleCreator,
      String() => ValueFactory.stringCreator,
      BigInt() => ValueFactory.bigIntCreator,
      DateTime() => ValueFactory.dateTimeCreator,
      Date() => ValueFactory.dateCreator,
      TimeWithOffset() => ValueFactory.timeWithOffsetCreator,
      Time() => ValueFactory.timeCreator,
      Interval() => ValueFactory.intervalCreator,
      Uint8List() => ValueFactory.blobCreator,
      Map<String, Object>() => ValueFactory.structCreator as ValueCreator,
      _ => throw UnsupportedError(
          'Unsupported value type: ${value.runtimeType}',
        ),
    };
  }

  ValueCreator _getListValueHandler(List<Object> list) {
    if (list.isEmpty) {
      throw ArgumentError('Cannot determine type of empty list');
    }

    return switch (list.first) {
      int() => ValueFactory.listOfInt,
      bool() => ValueFactory.listOfBool,
      double() => ValueFactory.listOfDouble,
      String() => ValueFactory.listOfString,
      BigInt() => ValueFactory.listOfBigInt,
      DateTime() => ValueFactory.listOfDateTime,
      Date() => ValueFactory.listOfDate,
      TimeWithOffset() => ValueFactory.listOfTimeWithOffset,
      Time() => ValueFactory.listOfTime,
      Interval() => ValueFactory.listOfInterval,
      Uint8List() => ValueFactory.listOfBlob,
      _ => throw UnsupportedError(
          'Unsupported list element type: ${list.first.runtimeType}',
        ),
    };
  }

  LogicalType _createStructType(
    Bindings bindings,
    List<LogicalType> memberTypes,
    List<String> memberNames,
  ) {
    final typeArray = allocate<duckdb_logical_type>(memberTypes.length);
    final nameArray = allocate<Pointer<Char>>(memberNames.length);

    try {
      // Fill arrays
      for (var i = 0; i < memberTypes.length; i++) {
        typeArray[i] = memberTypes[i].handle.value;
        nameArray[i] = memberNames[i].toNativeUtf8().cast<Char>();
      }

      final structType = allocate<duckdb_logical_type>();

      // Create struct type
      structType.value = bindings.duckdb_create_struct_type(
        typeArray,
        nameArray,
        memberTypes.length,
      );

      return LogicalType.withLogicalType(structType);
    } finally {
      // Free name strings
      for (var i = 0; i < memberNames.length; i++) {
        nameArray[i].free();
      }
      typeArray.free();
      nameArray.free();
    }
  }
}
