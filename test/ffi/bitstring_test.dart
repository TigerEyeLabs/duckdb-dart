// ignore: library_annotations
@TestOn('vm')

import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:test/test.dart';

void main() {
  late Database database;
  late Connection connection;

  setUp(() async {
    database = await duckdb.open(":memory:");
    connection = await duckdb.connect(database);
  });

  tearDown(() async {
    await connection.dispose();
    await database.dispose();
  });

  test('create bitstring from string', () async {
    final result =
        (await connection.query("SELECT '101010'::BITSTRING AS b;")).fetchAll();
    expect(result[0][0], '101010');
  });

  test('create bitstring with predefined length', () async {
    final result =
        (await connection.query("SELECT bitstring('0101011', 12) AS b;"))
            .fetchAll();
    expect(result[0][0], '000000101011');
  });

  test('convert integer to bitstring', () async {
    final result =
        (await connection.query("SELECT 123::BITSTRING AS b;")).fetchAll();
    expect(result[0][0], '00000000000000000000000001111011');
  });

  test('bitstring length', () async {
    final result =
        (await connection.query("SELECT length('101010'::BITSTRING) AS len;"))
            .fetchAll();
    expect(result[0][0], 6);
  });
}
