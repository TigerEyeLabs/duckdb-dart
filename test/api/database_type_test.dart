// ignore: library_annotations
@TestOn('vm')

import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:dart_duckdb/src/ffi/impl/database_type_native.dart';
import 'package:test/test.dart';

void main() {
  test('Ensure DatabaseType has the right order and uniqueness', () {
    final values = <int>{};
    for (final type in DatabaseTypeNative.values) {
      expect(
        values.contains(type.index),
        isFalse,
        reason: 'Duplicate index found for $type',
      );
      values.add(type.index);
      expect(
        type,
        equals(DatabaseTypeFactory.fromValue(type.index)),
        reason: 'Enum type $type does not match its index',
      );
    }
  });

  test('Verify that fromValue matches the enum type', () {
    for (final type in DatabaseTypeNative.values) {
      final resolvedType = DatabaseTypeFactory.fromValue(type.index);
      expect(
        resolvedType,
        equals(type),
        reason:
            'fromValue(${type.index}) returned $resolvedType instead of $type',
      );
    }
  });

  test('Verify isNumeric property', () {
    for (final type in DatabaseTypeNative.values) {
      final expectedNumeric = type.dartType == int ||
          type.dartType == double ||
          type.dartType == BigInt;
      expect(
        type.isNumeric,
        expectedNumeric,
        reason:
            'isNumeric property mismatch for $type with Dart type ${type.dartType}',
      );
    }
  });

  test('Verify isDate property', () {
    for (final type in DatabaseTypeNative.values) {
      final expectedDate = type.dartType == DateTime || type.dartType == Date;
      expect(
        type.isDate,
        expectedDate,
        reason:
            'isDate property mismatch for $type with Dart type ${type.dartType}',
      );
    }
  });
}
