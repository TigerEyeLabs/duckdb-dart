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

  test('simple uuid', () async {
    const uuidString = '79700043-11eb-1101-80d6-510900000d10';
    final results =
        (await connection.query("SELECT '$uuidString'::UUID;")).fetchAll();

    final uuid = results[0][0]!.toString();
    expect(uuid, uuidString);
  });
}
