import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:test/test.dart';

void main() {
  late Database database;
  late Connection connection;

  setUp(() {
    database = duckdb.open(':memory:');
    connection = duckdb.connect(database);
  });

  tearDown(() {
    connection.dispose();
    database.dispose();
  });

  T query<T>(String sql) {
    final results = connection.query(sql).fetchAll();
    final interval = results[0][0] as T;
    return interval;
  }

  Interval queryInterval(String sql) {
    return query<Interval>(sql);
  }

  test('Interval Years', () {
    expect(queryInterval('SELECT INTERVAL 5 years'), Interval(months: 5 * 12));
  });

  test('Interval Years as Months', () {
    expect(queryInterval("SELECT INTERVAL 15 months"), Interval(months: 15));
  });

  test('Interval Months', () {
    expect(queryInterval("SELECT INTERVAL 5 months"), Interval(months: 5));
  });

  test('Interval Days', () {
    expect(queryInterval("SELECT INTERVAL 5 days"), Interval(days: 5));
  });

  test('Interval Hours', () {
    expect(
      queryInterval("SELECT INTERVAL 5 hours"),
      Interval.fromParts(hours: 5),
    );
  });

  test('Interval Minutes', () {
    expect(
      queryInterval("SELECT INTERVAL 5 minutes"),
      Interval.fromParts(minutes: 5),
    );
  });

  test('Interval Seconds', () {
    expect(
      queryInterval("SELECT INTERVAL 5 seconds"),
      Interval.fromParts(seconds: 5),
    );
  });

  test('Interval Milliseconds', () {
    expect(
      queryInterval("SELECT INTERVAL 5 milliseconds"),
      Interval.fromParts(milliseconds: 5),
    );
  });

  test('Interval Microseconds', () {
    expect(
      queryInterval("SELECT INTERVAL 1500 microseconds"),
      Interval(microseconds: 1500),
    );
  });

  test('Interval Flavors', () {
    expect(
      query<DateTime>("SELECT DATE '2000-01-01' + INTERVAL 1 YEAR"),
      DateTime.utc(2001),
    );
    expect(
      query<DateTime>("SELECT DATE '2000-01-01' - INTERVAL 1 YEAR"),
      DateTime.utc(1999),
    );
    expect(
      queryInterval("SELECT INTERVAL (i) YEAR FROM range(1, 2) t(i)"),
      Interval.fromParts(years: 1),
    );
    expect(
      queryInterval("SELECT INTERVAL '1 month 1 day'"),
      Interval.fromParts(months: 1, days: 1),
    );
    expect(
      queryInterval(
        "SELECT INTERVAL '1.5' YEARS; --WARNING! This returns 1 year!",
      ),
      Interval.fromParts(years: 1),
    );
    expect(
      queryInterval(
        "SELECT TIMESTAMP '2000-02-01 12:00:00' - TIMESTAMP '2000-01-01 11:00:00' AS diff",
      ),
      Interval.fromParts(days: 31, hours: 1),
    );
  });

  test('From Parts', () {
    final interval = Interval.fromParts(
      years: 1,
      months: 2,
      days: 3,
      hours: 4,
      minutes: 5,
      seconds: 6,
      milliseconds: 7,
      microseconds: 8,
    );

    final newInterval = Interval(
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
