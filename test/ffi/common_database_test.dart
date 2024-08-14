import 'package:dart_duckdb/open.dart';
import 'package:test/test.dart';

void main() {
  final hasColumnMeta = open.openDuckDB().providesSymbol('duckdb_column_name');

  test('isNullPointer', () {
    expect(hasColumnMeta, true);
  });
}
