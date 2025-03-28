// ignore: library_annotations
@TestOn('vm')

import 'package:dart_duckdb/src/ffi/load_library.dart';
import 'package:test/test.dart';

void main() {
  final hasColumnMeta = (open as OpenDynamicLibrary)
      .openDuckDB()
      .providesSymbol('duckdb_column_name');

  test('isNullPointer', () {
    expect(hasColumnMeta, true);
  });
}
