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
}
