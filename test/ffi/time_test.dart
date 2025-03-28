import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:dart_duckdb/src/types/time.dart';

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

  test('query should return TIME value', () async {
    final result =
        (await connection.query("SELECT TIME '11:30:00.123456';")).fetchAll();
    expect(result[0][0], isA<Time>());
    expect(result[0][0].toString(), '11:30:00.123456');
  });

  test('query should return TIME value with milliseconds', () async {
    final result =
        (await connection.query("SELECT TIME '14:45:30.500';")).fetchAll();
    expect(result[0][0], isA<Time>());
    expect(result[0][0].toString(), '14:45:30.500000');
  });

  test('query should return TIME value without milliseconds', () async {
    final result =
        (await connection.query("SELECT TIME '09:15:45';")).fetchAll();
    expect(result[0][0], isA<Time>());
    expect(result[0][0].toString(), '09:15:45.000000');
  });

  test('query should compare TIME values', () async {
    final result = (await connection
            .query("SELECT TIME '10:00:00' < TIME '11:00:00' as comparison;"))
        .fetchAll();
    expect(result[0][0], isTrue);
  });
}
