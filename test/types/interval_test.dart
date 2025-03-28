import 'package:dart_duckdb/dart_duckdb.dart' as api;
import 'package:test/test.dart';

void main() {
  late api.Database database;
  late api.Connection connection;

  setUp(() async {
    database = await api.duckdb.open(':memory:');
    connection = await api.duckdb.connect(database);
  });

  tearDown(() async {
    await connection.dispose();
    await database.dispose();
  });

  Future<T> query<T>(String sql) async {
    final results = (await connection.query(sql)).fetchAll();
    final interval = results[0][0] as T;
    return interval;
  }

  Future<api.Interval> queryInterval(String sql) async {
    return query<api.Interval>(sql);
  }

  test('Interval Years', () async {
    expect(
      await queryInterval('SELECT INTERVAL 5 years'),
      api.Interval(months: 5 * 12),
    );
  });

  test('Interval Years as Months', () async {
    expect(
      await queryInterval("SELECT INTERVAL 15 months"),
      api.Interval(months: 15),
    );
  });

  test('Interval Months', () async {
    expect(
      await queryInterval("SELECT INTERVAL 5 months"),
      api.Interval(months: 5),
    );
  });

  test('Interval Days', () async {
    expect(
      await queryInterval("SELECT INTERVAL 5 days"),
      api.Interval(days: 5),
    );
  });

  test('Interval Hours', () async {
    expect(
      await queryInterval("SELECT INTERVAL 5 hours"),
      api.Interval.fromParts(hours: 5),
    );
  });

  test('Interval Minutes', () async {
    expect(
      await queryInterval("SELECT INTERVAL 5 minutes"),
      api.Interval.fromParts(minutes: 5),
    );
  });

  test('Interval Seconds', () async {
    expect(
      await queryInterval("SELECT INTERVAL 5 seconds"),
      api.Interval.fromParts(seconds: 5),
    );
  });

  test('Interval Milliseconds', () async {
    expect(
      await queryInterval("SELECT INTERVAL 5 milliseconds"),
      api.Interval.fromParts(milliseconds: 5),
    );
  });

  test('Interval Microseconds', () async {
    expect(
      await queryInterval("SELECT INTERVAL 1500 microseconds"),
      api.Interval(microseconds: 1500),
    );
  });

  test('Interval Flavors', () async {
    expect(
      await query<DateTime>("SELECT DATE '2000-01-01' + INTERVAL 1 YEAR"),
      DateTime.utc(2001),
    );
    expect(
      await query<DateTime>("SELECT DATE '2000-01-01' - INTERVAL 1 YEAR"),
      DateTime.utc(1999),
    );
    expect(
      await queryInterval("SELECT INTERVAL (i) YEAR FROM range(1, 2) t(i)"),
      api.Interval.fromParts(years: 1),
    );
    expect(
      await queryInterval("SELECT INTERVAL '1 month 1 day'"),
      api.Interval.fromParts(months: 1, days: 1),
    );
    expect(
      await queryInterval(
        "SELECT INTERVAL '1.5' YEARS; --WARNING! This returns 1 year!",
      ),
      api.Interval.fromParts(years: 1),
    );
    expect(
      await queryInterval(
        "SELECT TIMESTAMP '2000-02-01 12:00:00' - TIMESTAMP '2000-01-01 11:00:00' AS diff",
      ),
      api.Interval.fromParts(days: 31, hours: 1),
    );
  });

  test('From Parts', () async {
    final interval = api.Interval.fromParts(
      years: 1,
      months: 2,
      days: 3,
      hours: 4,
      minutes: 5,
      seconds: 6,
      milliseconds: 7,
      microseconds: 8,
    );

    final newInterval = api.Interval(
      months: interval.months,
      days: interval.days,
      microseconds: interval.microseconds,
    );

    expect(interval, newInterval);
    expect(newInterval.yearsPart, 1);
    expect(newInterval.monthsPart, 2);
    expect(newInterval.daysPart, 3);
    expect(newInterval.hoursPart, 4);
    expect(newInterval.minutesPart, 5);
    expect(newInterval.secondsPart, 6);
    expect(newInterval.millisecondsPart, 7);
    expect(newInterval.microsecondsPart, 8);
  });
}
