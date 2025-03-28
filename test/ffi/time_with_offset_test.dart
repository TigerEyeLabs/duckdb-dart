// ignore: library_annotations
@TestOn('vm')

import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:dart_duckdb/src/types/time_with_offset.dart';
import 'package:test/test.dart';

void main() {
  late Database database;
  late Connection connection;

  setUp(() async {
    database = await duckdb.open(":memory:");
    connection = await duckdb.connect(database);
    await connection.execute("Set TimeZone='GMT';");
  });

  tearDown(() async {
    await connection.dispose();
    await database.dispose();
  });

  test('query should return TIMETZ value', () async {
    final result =
        (await connection.query("SELECT TIMETZ '11:30:00.123456';")).fetchAll();
    expect(result[0][0], isA<TimeWithOffset>());
    expect(result[0][0].toString(), '11:30:00.123456+00');
  });

  test('query should return TIMETZ value with timezone offset', () async {
    final result =
        (await connection.query("SELECT TIMETZ '11:30:00.123456-02:00';"))
            .fetchAll();
    expect(result[0][0], isA<TimeWithOffset>());
    expect(result[0][0].toString(), '13:30:00.123456+00');
  });

  test('query should return TIMETZ value with positive timezone offset',
      () async {
    final result =
        (await connection.query("SELECT TIMETZ '11:30:00.123456+05:30';"))
            .fetchAll();
    expect(result[0][0], isA<TimeWithOffset>());
    expect(result[0][0].toString(), '06:00:00.123456+00');
  });

  test('query should compare TIMETZ values', () async {
    final result = (await connection.query(
      "SELECT TIMETZ '10:00:00+01:00' < TIMETZ '11:00:00+01:00' as comparison;",
    ))
        .fetchAll();
    expect(result[0][0], isTrue);
  });
}
