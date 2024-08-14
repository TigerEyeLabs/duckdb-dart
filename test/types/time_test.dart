import 'package:dart_duckdb/src/types/time.dart';
import 'package:test/test.dart';

void main() {
  group('Time', () {
    test('constructor initializes correctly', () {
      final time = Time(hour: 12, minute: 30, second: 45, microsecond: 123456);

      expect(time.hour, 12);
      expect(time.minute, 30);
      expect(time.second, 45);
      expect(time.microsecond, 123456);
    });

    test('constructor throws assertion error for invalid hour', () {
      expect(
        () => Time(hour: 24, minute: 30, second: 45, microsecond: 123456),
        throwsA(isA<AssertionError>()),
      );
    });

    test('constructor throws assertion error for invalid minute', () {
      expect(
        () => Time(hour: 12, minute: 60, second: 45, microsecond: 123456),
        throwsA(isA<AssertionError>()),
      );
    });

    test('constructor throws assertion error for invalid second', () {
      expect(
        () => Time(hour: 12, minute: 30, second: 60, microsecond: 123456),
        throwsA(isA<AssertionError>()),
      );
    });

    test('truncateDateTime initializes correctly', () {
      final time = Time(hour: 12, minute: 30, second: 45, microsecond: 123456);

      expect(time.hour, 12);
      expect(time.minute, 30);
      expect(time.second, 45);
      expect(time.microsecond, 123456);
    });

    test('toString returns correct format', () {
      final time = Time(hour: 12, minute: 5, second: 9, microsecond: 123);
      expect(time.toString(), '12:05:09.000123');
    });

    test('equality operator works correctly', () {
      final time1 = Time(hour: 12, minute: 30, second: 45, microsecond: 123456);
      final time2 = Time(hour: 12, minute: 30, second: 45, microsecond: 123456);
      final time3 = Time(hour: 13, minute: 30, second: 45, microsecond: 123456);

      expect(time1, equals(time2));
      expect(time1, isNot(equals(time3)));
    });

    test('hashCode works correctly', () {
      final time1 = Time(hour: 12, minute: 30, second: 45, microsecond: 123456);
      final time2 = Time(hour: 12, minute: 30, second: 45, microsecond: 123456);
      final time3 = Time(hour: 13, minute: 30, second: 45, microsecond: 123456);

      expect(time1.hashCode, equals(time2.hashCode));
      expect(time1.hashCode, isNot(equals(time3.hashCode)));
    });

    test('compareTo works correctly', () {
      final time1 = Time(hour: 12, minute: 30, second: 45, microsecond: 123456);
      final time2 = Time(hour: 13, minute: 30, second: 45, microsecond: 123456);
      final time3 = Time(hour: 12, minute: 30, second: 45, microsecond: 123456);

      expect(time1.compareTo(time2), lessThan(0));
      expect(time2.compareTo(time1), greaterThan(0));
      expect(time1.compareTo(time3), equals(0));
    });

    group('Time.fromMicrosecondsSinceEpoch', () {
      test(
          'should correctly convert microseconds since epoch to Time components',
          () {
        // 1st January 1970 00:00:00.000001 (UTC)
        var time = Time.fromMicrosecondsSinceEpoch(1);
        expect(time.hour, 0);
        expect(time.minute, 0);
        expect(time.second, 0);
        expect(time.microsecond, 1);

        // 1st January 1970 00:00:01.000000 (UTC)
        time = Time.fromMicrosecondsSinceEpoch(1000000);
        expect(time.hour, 0);
        expect(time.minute, 0);
        expect(time.second, 1);
        expect(time.microsecond, 0);

        // 1st January 1970 01:00:00.000000 (UTC)
        time = Time.fromMicrosecondsSinceEpoch(3600000000);
        expect(time.hour, 1);
        expect(time.minute, 0);
        expect(time.second, 0);
        expect(time.microsecond, 0);

        // 1st January 1970 12:34:56.789012 (UTC)
        time = Time.fromMicrosecondsSinceEpoch(45296789012);
        expect(time.hour, 12);
        expect(time.minute, 34);
        expect(time.second, 56);
        expect(time.microsecond, 789012);
      });

      test('should handle overflow of microseconds correctly', () {
        // 2nd January 1970 00:00:00.000000 (UTC)
        final time = Time.fromMicrosecondsSinceEpoch(86400000000);
        expect(time.hour, 0);
        expect(time.minute, 0);
        expect(time.second, 0);
        expect(time.microsecond, 0);
      });

      test('should handle different days correctly', () {
        // 2nd January 1970 12:34:56.789012 (UTC)
        final time = Time.fromMicrosecondsSinceEpoch(131696789012);
        expect(time.hour, 12);
        expect(time.minute, 34);
        expect(time.second, 56);
        expect(time.microsecond, 789012);
      });
    });
  });

  group('toMicrosecondsSinceEpoch', () {
    test('should convert 0:0:0.0 to 0', () {
      final time = Time(hour: 0, minute: 0, second: 0, microsecond: 0);
      expect(time.toMicrosecondsSinceEpoch(), 0);
    });

    test('should convert 0:0:1.0 to 1000000', () {
      final time = Time(hour: 0, minute: 0, second: 1, microsecond: 0);
      expect(time.toMicrosecondsSinceEpoch(), 1000000);
    });

    test('should convert 0:1:0.0 to 60000000', () {
      final time = Time(hour: 0, minute: 1, second: 0, microsecond: 0);
      expect(time.toMicrosecondsSinceEpoch(), 60000000);
    });

    test('should convert 1:0:0.0 to 3600000000', () {
      final time = Time(hour: 1, minute: 0, second: 0, microsecond: 0);
      expect(time.toMicrosecondsSinceEpoch(), 3600000000);
    });

    test('should convert 12:34:56.789012 to 45296789012', () {
      final time = Time(hour: 12, minute: 34, second: 56, microsecond: 789012);
      expect(time.toMicrosecondsSinceEpoch(), 45296789012);
    });

    test('should convert 23:59:59.999999 to 86399999999', () {
      final time = Time(hour: 23, minute: 59, second: 59, microsecond: 999999);
      expect(time.toMicrosecondsSinceEpoch(), 86399999999);
    });
  });
}
