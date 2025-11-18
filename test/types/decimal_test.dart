import 'package:dart_duckdb/src/types/decimal.dart';
import 'package:test/test.dart';

void main() {
  test('decimal drops trailing zeros', () {
    expect(Decimal.parse('100'), Decimal(BigInt.from(1000), 1));
    expect(Decimal.parse('101'), Decimal(BigInt.from(101)));
  });

  test('decimal shift works', () {
    final decimal = Decimal.parse('123.4567');
    expect(decimal.shift(-1), Decimal.parse('12.34567'));
    expect(decimal.shift(1), Decimal.parse('1234.567'));
  });

  test('decimal to big int works', () {
    expect(Decimal(BigInt.one).toBigInt(), BigInt.one);
    expect(Decimal(BigInt.from(10)).toBigInt(), BigInt.from(10));
    expect(Decimal(BigInt.from(100)).toBigInt(), BigInt.from(100));
  });

  group('Decimal', () {
    final decimals = {
      ".0": Decimal.zero,
      ".1": Decimal(BigInt.one, 1),
      "1.1": Decimal(BigInt.from(11), 1),
      "-1.1": Decimal(BigInt.from(-11), 1),
      "123": Decimal(BigInt.from(123)),
      "+123": Decimal(BigInt.from(123)),
      "-123": Decimal(BigInt.from(-123)),
      "123.456": Decimal(BigInt.from(123456), 3),
      "-123.456": Decimal(BigInt.from(-123456), 3),
      "1.23e3": Decimal(BigInt.from(123), -1),
      "-1.23e3": Decimal(BigInt.from(-123), -1),
      "1.23e-3": Decimal(BigInt.from(123), 5),
      "+1.23e-3": Decimal(BigInt.from(123), 5),
    };

    for (final entry in decimals.entries) {
      final decimal = Decimal.parse(entry.key);

      test("parse: ${entry.key}", () {
        expect(decimal, entry.value);
      });

      test("compareTo: ${entry.key}", () {
        expect(decimal.compareTo(entry.value), 0);
      });

      test("toDouble: ${entry.key}", () {
        expect(decimal.toDouble(), double.parse(entry.key));
      });
    }
  });

  group('Decimal toString formatting', () {
    test('should format scale 0 without exponential notation', () {
      // These should display as regular integers, not exponential notation
      expect(Decimal(BigInt.from(2), 0).toString(), equals('2'));
      expect(Decimal(BigInt.from(48), 0).toString(), equals('48'));
      expect(Decimal(BigInt.from(6052), 0).toString(), equals('6052'));
      expect(Decimal(BigInt.from(1000), 0).toString(), equals('1000'));
    });

    test('should format positive scale with decimal points', () {
      // These should display with proper decimal points
      expect(Decimal(BigInt.from(12345), 2).toString(), equals('123.45'));
      expect(Decimal(BigInt.from(300125), 2).toString(), equals('3001.25'));
      expect(Decimal(BigInt.from(225050), 2).toString(), equals('2250.5'));
      expect(Decimal(BigInt.from(4850), 2).toString(), equals('48.5'));
    });

    test('should format negative scale correctly', () {
      // Negative scale means multiply by powers of 10
      expect(Decimal(BigInt.from(3), -2).toString(), equals('300'));
      expect(Decimal(BigInt.from(5), -1).toString(), equals('50'));
      expect(Decimal(BigInt.from(123), -3).toString(), equals('123000'));
    });

    test('should handle zero correctly', () {
      expect(Decimal.zero.toString(), equals('0'));
      expect(Decimal(BigInt.zero, 0).toString(), equals('0'));
      expect(Decimal(BigInt.zero, 2).toString(), equals('0'));
    });

    test('should handle negative numbers correctly', () {
      expect(Decimal(BigInt.from(-2), 0).toString(), equals('-2'));
      expect(Decimal(BigInt.from(-12345), 2).toString(), equals('-123.45'));
      expect(Decimal(BigInt.from(-3), -2).toString(), equals('-300'));
    });

    test('should not use exponential notation for common aggregation results',
        () {
      // Simulate common SQL aggregation results that were causing issues
      final countResult =
          Decimal(BigInt.from(2), 0); // SUM(CASE WHEN ... THEN 1 ELSE 0 END)
      final sumResult = Decimal(BigInt.from(6), 0); // SUM(1) FROM table
      final totalResult =
          Decimal(BigInt.from(6052), 0); // SUM(amount) when scale is 0

      expect(countResult.toString(), equals('2'));
      expect(countResult.toString(), isNot(contains('e')));

      expect(sumResult.toString(), equals('6'));
      expect(sumResult.toString(), isNot(contains('e')));

      expect(totalResult.toString(), equals('6052'));
      expect(totalResult.toString(), isNot(contains('e')));
    });

    test('should handle small decimal values correctly', () {
      // Test cases that might have caused exponential notation
      expect(Decimal(BigInt.from(1), 2).toString(), equals('0.01'));
      expect(Decimal(BigInt.from(3), 2).toString(), equals('0.03'));
      expect(Decimal(BigInt.from(5), 3).toString(), equals('0.005'));
    });
  });
}
