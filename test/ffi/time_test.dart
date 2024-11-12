import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:dart_duckdb/src/types/time.dart';
import 'package:dart_duckdb/src/types/time_with_offset.dart';
import 'package:test/test.dart';

void main() {
  late Database database;
  late Connection connection;

  setUp(() {
    database = duckdb.open(":memory:");
    connection = duckdb.connect(database);
    connection.execute("Set TimeZone='GMT';");
  });

  tearDown(() {
    connection.dispose();
    database.dispose();
  });

  test('query should return TIME value', () {
    final result =
        connection.query("SELECT TIME '11:30:00.123456';").fetchAll();
    expect(result[0][0], isA<Time>());
    expect(result[0][0].toString(), '11:30:00.123456');
  });

  test('query should return TIME value with milliseconds', () {
    final result = connection.query("SELECT TIME '14:45:30.500';").fetchAll();
    expect(result[0][0], isA<Time>());
    expect(result[0][0].toString(), '14:45:30.500000');
  });

  test('query should return TIME value without milliseconds', () {
    final result = connection.query("SELECT TIME '09:15:45';").fetchAll();
    expect(result[0][0], isA<Time>());
    expect(result[0][0].toString(), '09:15:45.000000');
  });

  test('query should compare TIME values', () {
    final result = connection
        .query("SELECT TIME '10:00:00' < TIME '11:00:00' as comparison;")
        .fetchAll();
    expect(result[0][0], isTrue);
  });

  test('query should return TIMETZ value', () {
    final result =
        connection.query("SELECT TIMETZ '11:30:00.123456';").fetchAll();
    expect(result[0][0], isA<TimeWithOffset>());
    expect(result[0][0].toString(), '11:30:00.123456+00');
  });

  test('query should return TIMETZ value with timezone offset', () {
    final result =
        connection.query("SELECT TIMETZ '11:30:00.123456-02:00';").fetchAll();
    expect(result[0][0], isA<TimeWithOffset>());
    expect(result[0][0].toString(), '13:30:00.123456+00');
  });

  test('query should return TIMETZ value with positive timezone offset', () {
    final result =
        connection.query("SELECT TIMETZ '11:30:00.123456+05:30';").fetchAll();
    expect(result[0][0], isA<TimeWithOffset>());
    expect(result[0][0].toString(), '06:00:00.123456+00');
  });

  test('query should compare TIMETZ values', () {
    final result = connection
        .query(
          "SELECT TIMETZ '10:00:00+01:00' < TIMETZ '11:00:00+01:00' as comparison;",
        )
        .fetchAll();
    expect(result[0][0], isTrue);
  });
}
