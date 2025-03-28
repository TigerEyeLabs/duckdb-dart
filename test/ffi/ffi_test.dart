// ignore: library_annotations
@TestOn('vm')

import 'dart:ffi';

import 'package:dart_duckdb/src/ffi/impl/utils.dart';
import 'package:test/test.dart';

void main() {
  test('isNullPointer', () {
    expect(Pointer.fromAddress(1).isNullPointer, isFalse);
    expect(Pointer.fromAddress(0).isNullPointer, isTrue);
  });
}
