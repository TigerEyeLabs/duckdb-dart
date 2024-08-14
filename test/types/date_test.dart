import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:test/test.dart';

void main() {
  group('Date', () {
    test('constructor initializes correctly', () {
      // Equivalent to 2020-12-31
      const date = Date(18627);
      expect(date.daysSinceEpoch, 18627);
    });

    test('ymd constructor initializes correctly', () {
      final date = Date.ymd(1970, 1, 2);
      expect(date.daysSinceEpoch, 1);
    });

    test('ymd constructor initializes correctly', () {
      final date = Date.ymd(2020, 12, 31);
      expect(date.daysSinceEpoch, 18627);
    });

    test('fromDateTime initializes correctly', () {
      final dateTime = DateTime.utc(2020, 12, 31);
      final date = Date.fromDateTime(dateTime);
      expect(date.daysSinceEpoch, 18627);
    });

    test('toDateTime converts correctly', () {
      const date = Date(18627);
      final dateTime = date.toDateTime();
      expect(dateTime.year, 2020);
      expect(dateTime.month, 12);
      expect(dateTime.day, 31);
    });

    test('toString returns correct format', () {
      const date = Date(18627);
      expect(date.toString(), '2020-12-31');
    });

    test('equality operator works correctly', () {
      const date1 = Date(18627);
      const date2 = Date(18627);
      const date3 = Date(18629);

      expect(date1, equals(date2));
      expect(date1, isNot(equals(date3)));
    });

    test('hashCode works correctly', () {
      const date1 = Date(18627);
      const date2 = Date(18627);
      const date3 = Date(18629);

      expect(date1.hashCode, equals(date2.hashCode));
      expect(date1.hashCode, isNot(equals(date3.hashCode)));
    });

    test('isBefore works correctly', () {
      const date1 = Date(18627);
      const date2 = Date(18629);

      expect(date1.isBefore(date2), isTrue);
      expect(date2.isBefore(date1), isFalse);
    });

    test('isAfter works correctly', () {
      const date1 = Date(18627);
      const date2 = Date(18629);

      expect(date1.isAfter(date2), isFalse);
      expect(date2.isAfter(date1), isTrue);
    });

    test('compareTo works correctly', () {
      const date1 = Date(18627);
      const date2 = Date(18629);
      const date3 = Date(18627);

      expect(date1.compareTo(date2), lessThan(0));
      expect(date2.compareTo(date1), greaterThan(0));
      expect(date1.compareTo(date3), equals(0));
    });
  });
}
